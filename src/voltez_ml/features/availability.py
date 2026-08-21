"""Point-in-time charger availability feature construction."""

from __future__ import annotations

import math
from bisect import bisect_right
from collections import defaultdict
from typing import Any, cast

import numpy as np
import pandas as pd

from voltez_ml.config import VoltEZConfig


def _records(frame: pd.DataFrame) -> list[dict[str, Any]]:
    return cast(list[dict[str, Any]], frame.to_dict("records"))


def _timestamp(value: Any) -> pd.Timestamp | None:
    if value is None or pd.isna(value):
        return None
    return pd.Timestamp(value)


def _clock_minute(value: str) -> int:
    hour, minute, _ = (int(part) for part in value.split(":"))
    return hour * 60 + minute


def _open_and_minutes_to_close(
    business_id: str,
    target: pd.Timestamp,
    hours: dict[tuple[str, int], dict[str, Any]],
) -> tuple[bool, int]:
    row = hours[(business_id, target.weekday())]
    target_minute = target.hour * 60 + target.minute
    opens = _clock_minute(str(row["opens_at"]))
    closes = _clock_minute(str(row["closes_at"]))
    is_open = opens <= target_minute < closes
    return is_open, max(0, closes - target_minute) if is_open else 0


def _enrich_ports(tables: dict[str, pd.DataFrame]) -> pd.DataFrame:
    ports = tables["charger_ports"].merge(
        tables["chargers"][
            [
                "charger_id",
                "business_id",
                "zone_id",
                "access_type",
                "status",
            ]
        ],
        on="charger_id",
        validate="many_to_one",
    )
    ports = ports.merge(
        tables["businesses"][["business_id", "category", "verification_status"]],
        on="business_id",
        validate="many_to_one",
    ).merge(
        tables["connector_types"][["connector_type_id", "code", "charging_type"]],
        on="connector_type_id",
        validate="many_to_one",
    )
    ports["site_port_count"] = ports.groupby("charger_id")["port_id"].transform("size")
    return ports


def _demand_prefixes(
    demand: pd.DataFrame,
    bucket_minutes: int,
) -> dict[tuple[str, str], tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]]:
    result: dict[tuple[str, str], tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]] = {}
    for (run_id, zone_id), group in demand.sort_values("bucket_start").groupby(
        ["simulation_run_id", "zone_id"], sort=False
    ):
        bucket_ends = (
            (group["bucket_start"] + pd.to_timedelta(bucket_minutes, unit="m"))
            .astype("int64")
            .to_numpy()
        )
        request_prefix = np.concatenate(
            ([0.0], group["request_count"].to_numpy(dtype=float).cumsum())
        )
        unserved_prefix = np.concatenate(
            ([0.0], group["unserved_count"].to_numpy(dtype=float).cumsum())
        )
        occupancy_prefix = np.concatenate(
            ([0.0], group["occupancy_rate"].to_numpy(dtype=float).cumsum())
        )
        result[(str(run_id), str(zone_id))] = (
            bucket_ends,
            request_prefix,
            unserved_prefix,
            occupancy_prefix,
        )
    return result


def _recent_demand(
    origin: pd.Timestamp,
    values: tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray],
) -> tuple[float, float, float, pd.Timestamp | None]:
    bucket_ends, request_prefix, unserved_prefix, occupancy_prefix = values
    origin_ns = origin.value
    lower_ns = (origin - pd.to_timedelta(1, unit="h")).value
    end_index = int(np.searchsorted(bucket_ends, origin_ns, side="right"))
    start_index = int(np.searchsorted(bucket_ends, lower_ns, side="right"))
    count = end_index - start_index
    if count <= 0:
        return 0.0, 0.0, 0.0, None
    latest_end = pd.Timestamp(int(bucket_ends[end_index - 1]), tz=origin.tz)
    return (
        float(request_prefix[end_index] - request_prefix[start_index]),
        float(unserved_prefix[end_index] - unserved_prefix[start_index]),
        float((occupancy_prefix[end_index] - occupancy_prefix[start_index]) / count),
        latest_end,
    )


def build_availability_features(
    config: VoltEZConfig,
    tables: dict[str, pd.DataFrame],
) -> pd.DataFrame:
    """Build Model 2 rows using only evidence ingested by each prediction origin."""

    ports = _enrich_ports(tables)
    port_lookup = {str(row["port_id"]): row for row in _records(ports)}
    hours_lookup = {
        (str(row["business_id"]), int(row["day_of_week"])): row
        for row in _records(tables["business_hours"])
    }
    bookings_by_port: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in _records(tables["bookings"]):
        bookings_by_port[str(row["port_id"])].append(row)
    sessions_by_port: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in _records(tables["charging_sessions"]):
        sessions_by_port[str(row["port_id"])].append(row)
    status_by_port: dict[str, list[dict[str, Any]]] = defaultdict(list)
    status_ingestion_times: dict[str, list[pd.Timestamp]] = {}
    for row in _records(tables["charger_status_events"]):
        status_by_port[str(row["port_id"])].append(row)
    for port_id, status_rows in status_by_port.items():
        status_rows.sort(key=lambda row: pd.Timestamp(row["ingested_at"]))
        status_ingestion_times[port_id] = [pd.Timestamp(row["ingested_at"]) for row in status_rows]
    own_booking_lookup = {
        (str(row["request_id"]), str(row["port_id"])): str(row["booking_id"])
        for row in _records(tables["recommendation_impressions"])
        if row.get("booking_id") is not None and not pd.isna(row["booking_id"])
    }
    demand_prefixes = _demand_prefixes(tables["demand_buckets"], config.time.bucket_minutes)
    history_window = pd.to_timedelta(config.features.availability_history_hours, unit="h")
    reliability_window = pd.to_timedelta(config.features.reliability_history_days, unit="D")

    rows: list[dict[str, Any]] = []
    for observation in _records(tables["availability_observations"]):
        origin = pd.Timestamp(observation["prediction_origin"])
        target = pd.Timestamp(observation["target_arrival_at"])
        port_id = str(observation["port_id"])
        port = port_lookup[port_id]
        own_booking_id = own_booking_lookup.get((str(observation["request_id"]), port_id))

        known_conflicts = 0
        known_nearby_bookings = 0
        latest_booking_event: pd.Timestamp | None = None
        for booking in bookings_by_port[port_id]:
            if str(booking["booking_id"]) == own_booking_id:
                continue
            confirmed_at = _timestamp(booking.get("confirmed_at"))
            cancelled_at = _timestamp(booking.get("cancelled_at"))
            if confirmed_at is None or confirmed_at > origin:
                continue
            if cancelled_at is not None and cancelled_at <= origin:
                latest_booking_event = max(
                    latest_booking_event or cancelled_at,
                    cancelled_at,
                )
                continue
            latest_booking_event = max(latest_booking_event or confirmed_at, confirmed_at)
            booking_start = pd.Timestamp(booking["start_at"])
            booking_end = pd.Timestamp(booking["end_at"])
            if booking_start < target + pd.to_timedelta(1, unit="m") and target < booking_end:
                known_conflicts += 1
            if (
                booking_start < target + pd.to_timedelta(2, unit="h")
                and target - pd.to_timedelta(2, unit="h") < booking_end
            ):
                known_nearby_bookings += 1

        active_sessions = 0
        active_elapsed_minutes = 0.0
        prior_successes = 0
        prior_failures = 0
        reliability_successes = 0
        reliability_charger_failures = 0
        reliability_congestion_failures = 0
        latest_session_event: pd.Timestamp | None = None
        for session in sessions_by_port[port_id]:
            start_at = _timestamp(session.get("start_at"))
            end_at = _timestamp(session.get("end_at"))
            check_in_at = _timestamp(session.get("check_in_at"))
            if start_at is not None and start_at <= origin and (end_at is None or end_at > origin):
                active_sessions += 1
                active_elapsed_minutes = max(
                    active_elapsed_minutes,
                    max(0.0, (origin - start_at).total_seconds() / 60),
                )
                latest_session_event = max(latest_session_event or start_at, start_at)
            if (
                session["status"] == "completed"
                and end_at is not None
                and origin - history_window <= end_at <= origin
            ):
                prior_successes += 1
                latest_session_event = max(latest_session_event or end_at, end_at)
            elif (
                session["status"] == "failed"
                and check_in_at is not None
                and origin - history_window <= check_in_at <= origin
            ):
                prior_failures += 1
                latest_session_event = max(latest_session_event or check_in_at, check_in_at)

            outcome_at = end_at if end_at is not None else check_in_at
            if outcome_at is not None and origin - reliability_window <= outcome_at <= origin:
                latest_session_event = max(latest_session_event or outcome_at, outcome_at)
                if session["status"] == "completed":
                    reliability_successes += 1
                elif session["status"] == "failed":
                    failure_reason = str(session.get("failure_reason") or "")
                    if failure_reason.startswith("charger_fault"):
                        reliability_charger_failures += 1
                    elif failure_reason == "occupied_overrun":
                        reliability_congestion_failures += 1

        evidence_count = prior_successes + prior_failures
        smoothed_reliability = (prior_successes + config.features.reliability_prior_successes) / (
            evidence_count
            + config.features.reliability_prior_successes
            + config.features.reliability_prior_failures
        )
        charger_reliability_evidence = reliability_successes + reliability_charger_failures
        smoothed_charger_reliability = (
            reliability_successes + config.features.reliability_prior_successes
        ) / (
            charger_reliability_evidence
            + config.features.reliability_prior_successes
            + config.features.reliability_prior_failures
        )

        latest_status: dict[str, Any] | None = None
        known_status_rows = status_by_port.get(port_id, [])
        if known_status_rows:
            status_index = bisect_right(status_ingestion_times[port_id], origin) - 1
            if status_index >= 0:
                latest_status = known_status_rows[status_index]
        status_ingested_at = (
            pd.Timestamp(latest_status["ingested_at"]) if latest_status is not None else None
        )
        status_observed_at = (
            pd.Timestamp(latest_status["observed_at"]) if latest_status is not None else None
        )
        status_expires_at = (
            pd.Timestamp(latest_status["expires_at"]) if latest_status is not None else None
        )

        recent_requests, recent_unserved, recent_occupancy, demand_cutoff = _recent_demand(
            origin,
            demand_prefixes[(str(observation["simulation_run_id"]), str(port["zone_id"]))],
        )
        business_open, minutes_to_close = _open_and_minutes_to_close(
            str(port["business_id"]), target, hours_lookup
        )
        eta_minutes = (target - origin).total_seconds() / 60
        target_hour = target.hour + target.minute / 60
        target_day = target.dayofweek
        feature_times = [
            value
            for value in (
                latest_booking_event,
                latest_session_event,
                status_ingested_at,
                demand_cutoff,
            )
            if value is not None
        ]
        rows.append(
            {
                "observation_id": observation["observation_id"],
                "request_id": observation["request_id"],
                "port_id": port_id,
                "charger_id": port["charger_id"],
                "zone_id": port["zone_id"],
                "simulation_run_id": observation["simulation_run_id"],
                "source_snapshot_id": observation["source_snapshot_id"],
                "prediction_origin": origin,
                "feature_cutoff": origin,
                "target_time": target,
                "eta_minutes": eta_minutes,
                "target_hour_sin": math.sin(2 * math.pi * target_hour / 24),
                "target_hour_cos": math.cos(2 * math.pi * target_hour / 24),
                "target_day_sin": math.sin(2 * math.pi * target_day / 7),
                "target_day_cos": math.cos(2 * math.pi * target_day / 7),
                "target_is_weekend": int(target_day >= 5),
                "business_open_at_target": int(business_open),
                "minutes_to_business_close": minutes_to_close,
                "known_booking_conflicts": known_conflicts,
                "known_bookings_near_target": known_nearby_bookings,
                "active_session_count": active_sessions,
                "active_session_elapsed_minutes": active_elapsed_minutes,
                "prior_success_count": prior_successes,
                "prior_failure_count": prior_failures,
                "reliability_evidence_count": evidence_count,
                "smoothed_reliability": smoothed_reliability,
                "cold_start": int(evidence_count < config.features.cold_start_evidence_threshold),
                "prior_reliable_session_count": reliability_successes,
                "prior_charger_failure_count": reliability_charger_failures,
                "prior_congestion_failure_count": reliability_congestion_failures,
                "charger_reliability_evidence_count": charger_reliability_evidence,
                "smoothed_charger_reliability": smoothed_charger_reliability,
                "reliability_cold_start": int(
                    charger_reliability_evidence
                    < config.features.cold_start_evidence_threshold
                ),
                "latest_status": str(latest_status["status"])
                if latest_status is not None
                else "unknown",
                "latest_status_source": str(latest_status["source"])
                if latest_status is not None
                else "missing",
                "latest_status_confidence": float(latest_status["confidence"])
                if latest_status is not None
                else 0.0,
                "status_age_minutes": max(0.0, (origin - status_observed_at).total_seconds() / 60)
                if status_observed_at is not None
                else np.nan,
                "status_missing": int(latest_status is None),
                "status_expired": int(status_expires_at is None or status_expires_at <= origin),
                "recent_zone_requests_1h": recent_requests,
                "recent_zone_unserved_1h": recent_unserved,
                "recent_zone_occupancy_mean_1h": recent_occupancy,
                "connector_code": port["code"],
                "charging_type": port["charging_type"],
                "max_power_kw": port["max_power_kw"],
                "site_port_count": port["site_port_count"],
                "business_category": port["category"],
                "access_type": port["access_type"],
                "business_verification_status": port["verification_status"],
                "latest_booking_event_at": latest_booking_event,
                "latest_session_event_at": latest_session_event,
                "status_ingested_at_feature": status_ingested_at,
                "demand_cutoff_at": demand_cutoff,
                "latest_source_time": max(feature_times) if feature_times else origin,
                "label": observation["label"],
                "label_known": int(observation["label"] != "unknown"),
                "label_source": observation["label_source"],
                "label_confidence": observation["confidence"],
            }
        )
    return (
        pd.DataFrame(rows)
        .sort_values(
            ["simulation_run_id", "prediction_origin", "request_id", "port_id"],
            kind="mergesort",
        )
        .reset_index(drop=True)
    )
