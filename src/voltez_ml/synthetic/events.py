"""Causal request, booking, session, status, and analytics simulation."""

from __future__ import annotations

import json
import math
from collections import defaultdict
from datetime import date, timedelta
from typing import Any, cast

import numpy as np
import pandas as pd

from voltez_ml.config import VoltEZConfig
from voltez_ml.geography import haversine_km, nearest_neighbor_ids
from voltez_ml.route_energy.synthetic import generate_route_snapshots
from voltez_ml.synthetic.randomness import (
    named_rng,
    negative_binomial_parameters,
    stable_id,
)

SCENARIO_DEMAND_MULTIPLIERS = {
    "normal_weekday": 1.0,
    "weekend_retail": 1.25,
    "monsoon_disruption": 1.18,
    "local_event_spike": 1.85,
    "outage_cluster": 1.08,
    "stale_status_reports": 1.0,
}

SCENARIO_SEVERITY = {
    "normal_weekday": 0.0,
    "weekend_retail": 0.3,
    "monsoon_disruption": 0.75,
    "local_event_spike": 0.9,
    "outage_cluster": 0.8,
    "stale_status_reports": 0.6,
}


def _records(frame: pd.DataFrame) -> list[dict[str, Any]]:
    """Give pandas' dynamic records output a narrow type at one boundary."""

    return cast(list[dict[str, Any]], frame.to_dict("records"))


def _clock_minute(value: str) -> int:
    """Convert a local `HH:MM:SS` business-hour value to minutes after midnight."""

    hour, minute, _ = (int(part) for part in value.split(":"))
    return hour * 60 + minute


def _enriched_ports(static: dict[str, pd.DataFrame]) -> pd.DataFrame:
    """Join normalized v1.1 supply tables for simulator calculations only.

    The returned frame is never written as an application table. Keeping this join local lets
    the public `charger_ports` fixture remain normalized while the simulator can still reason
    about host, zone, connector, parking, and current tariff.
    """

    parking = static["parking_spaces"].sort_values(["charger_id", "label"], kind="mergesort").copy()
    parking["port_number"] = parking.groupby("charger_id").cumcount() + 1
    return (
        static["charger_ports"]
        .merge(
            static["chargers"][
                [
                    "charger_id",
                    "business_id",
                    "zone_id",
                    "latitude",
                    "longitude",
                    "access_type",
                    "status",
                ]
            ],
            on="charger_id",
        )
        .merge(
            static["connector_types"][["connector_type_id", "code", "charging_type"]],
            on="connector_type_id",
        )
        .merge(
            static["tariffs"][["port_id", "price_per_kwh", "price_per_minute", "booking_fee"]],
            on="port_id",
        )
        .merge(
            parking[["charger_id", "port_number", "parking_space_id"]],
            on=["charger_id", "port_number"],
        )
    )


def _intervals_overlap(
    first_start: pd.Timestamp,
    first_end: pd.Timestamp,
    second_start: pd.Timestamp,
    second_end: pd.Timestamp,
) -> bool:
    return bool(first_start < second_end and second_start < first_end)


def _is_business_open(
    business_id: str,
    moment: pd.Timestamp,
    hours_lookup: dict[tuple[str, int], dict[str, Any]],
) -> bool:
    hours = hours_lookup[(business_id, moment.weekday())]
    local_minute = moment.hour * 60 + moment.minute
    return bool(
        _clock_minute(str(hours["opens_at"]))
        <= local_minute
        < _clock_minute(str(hours["closes_at"]))
    )


def _daily_profile(bucket_count: int) -> np.ndarray:
    bucket_hours = (np.arange(bucket_count) + 0.5) * (24 / bucket_count)
    morning = 1.15 * np.exp(-0.5 * ((bucket_hours - 8.5) / 1.6) ** 2)
    midday = 0.55 * np.exp(-0.5 * ((bucket_hours - 13.0) / 2.2) ** 2)
    evening = 1.45 * np.exp(-0.5 * ((bucket_hours - 19.0) / 1.9) ** 2)
    profile = 0.22 + morning + midday + evening
    return profile / profile.sum()


def _scenario_tables(
    config: VoltEZConfig,
    run_id: str,
    zones: pd.DataFrame,
) -> tuple[pd.DataFrame, dict[tuple[str, date], str]]:
    rng = named_rng(config.project.seed, "scenarios")
    scenario_names = list(config.synthetic.scenario_mix)
    probabilities = np.array([config.synthetic.scenario_mix[name] for name in scenario_names])
    rows: list[dict[str, Any]] = []
    lookup: dict[tuple[str, date], str] = {}
    for day_offset in range(config.synthetic.days):
        local_date = config.synthetic.start_date + timedelta(days=day_offset)
        for zone_id in zones["zone_id"].astype(str):
            scenario = str(rng.choice(scenario_names, p=probabilities))
            lookup[(zone_id, local_date)] = scenario
            if scenario == "normal_weekday":
                continue
            start_at = pd.Timestamp(local_date, tz=config.project.timezone)
            rows.append(
                {
                    "context_event_id": stable_id(
                        run_id, "context-event", f"{zone_id}:{local_date.isoformat()}"
                    ),
                    "zone_id": zone_id,
                    "event_type": scenario,
                    "starts_at": start_at,
                    "ends_at": start_at + timedelta(days=1),
                    "expected_impact": SCENARIO_SEVERITY[scenario],
                    "source": "synthetic_scenario",
                    "published_at": start_at - timedelta(days=7),
                    "ingested_at": start_at - timedelta(days=7) + timedelta(minutes=1),
                    "simulation_run_id": run_id,
                }
            )
    columns = [
        "context_event_id",
        "zone_id",
        "event_type",
        "starts_at",
        "ends_at",
        "expected_impact",
        "source",
        "published_at",
        "ingested_at",
        "simulation_run_id",
    ]
    return pd.DataFrame(rows, columns=columns), lookup


def _generate_outages_and_initial_reports(
    config: VoltEZConfig,
    run_id: str,
    ports: pd.DataFrame,
    latent_port_profiles: pd.DataFrame,
    scenario_lookup: dict[tuple[str, date], str],
) -> tuple[pd.DataFrame, list[dict[str, Any]]]:
    outage_rng = named_rng(config.project.seed, "outages")
    report_rng = named_rng(config.project.seed, "status-reports")
    outages: list[dict[str, Any]] = []
    reports: list[dict[str, Any]] = []
    dataset_start = pd.Timestamp(config.synthetic.start_date, tz=config.project.timezone)
    health_lookup = {
        str(row["port_id"]): row for row in _records(latent_port_profiles)
    }

    for port in _records(ports):
        health = health_lookup[str(port["port_id"])]
        initial_error = bool(
            report_rng.random() < config.synthetic.availability.owner_report_error_probability
        )
        reports.append(
            {
                "status_event_id": stable_id(run_id, "status", f"initial:{port['port_id']}"),
                "charger_id": port["charger_id"],
                "port_id": port["port_id"],
                "status": "unknown" if initial_error else "available",
                "source": "owner",
                "confidence": 0.25 if initial_error else 0.75,
                "observed_at": dataset_start,
                "ingested_at": dataset_start + timedelta(minutes=int(report_rng.integers(1, 8))),
                "expires_at": dataset_start
                + timedelta(minutes=config.synthetic.availability.median_status_ttl_minutes),
                "evidence_type": "owner_declaration",
                "simulation_run_id": run_id,
            }
        )
        for day_offset in range(config.synthetic.days):
            local_date = config.synthetic.start_date + timedelta(days=day_offset)
            scenario = scenario_lookup[(str(port["zone_id"]), local_date)]
            outage_probability = 1 - float(health["daily_operational_probability"])
            if scenario == "outage_cluster":
                outage_probability = min(0.55, outage_probability + 0.35)
            if outage_rng.random() >= outage_probability:
                continue
            day_start = pd.Timestamp(local_date, tz=config.project.timezone)
            outage_start = day_start + timedelta(minutes=int(outage_rng.integers(0, 24 * 60 - 30)))
            repair_minutes = int(
                outage_rng.integers(30, 241) * float(health["repair_duration_multiplier"])
            )
            outage_end = min(
                day_start + timedelta(days=1),
                outage_start + timedelta(minutes=max(30, repair_minutes)),
            )
            outage_id = stable_id(run_id, "outage", f"{port['port_id']}:{local_date.isoformat()}")
            outages.append(
                {
                    "outage_id": outage_id,
                    "port_id": port["port_id"],
                    "zone_id": port["zone_id"],
                    "start_at": outage_start,
                    "end_at": outage_end,
                    "latent_reason": "simulated_fault",
                    "simulation_run_id": run_id,
                }
            )
            stale_multiplier = 4 if scenario == "stale_status_reports" else 1
            for marker, event_time, true_status in (
                ("start", outage_start, "faulted"),
                ("end", outage_end, "available"),
            ):
                error = bool(
                    report_rng.random()
                    < config.synthetic.availability.owner_report_error_probability
                )
                reported_status = "available" if true_status == "faulted" and error else true_status
                delay = int(report_rng.integers(2, 25)) * stale_multiplier
                reports.append(
                    {
                        "status_event_id": stable_id(
                            run_id, "status", f"outage:{outage_id}:{marker}"
                        ),
                        "charger_id": port["charger_id"],
                        "port_id": port["port_id"],
                        "status": reported_status,
                        "source": "owner",
                        "confidence": 0.35 if error else 0.75,
                        "observed_at": event_time,
                        "ingested_at": event_time + timedelta(minutes=delay),
                        "expires_at": event_time
                        + timedelta(
                            minutes=config.synthetic.availability.median_status_ttl_minutes
                            * stale_multiplier
                        ),
                        "evidence_type": "owner_declaration",
                        "simulation_run_id": run_id,
                    }
                )

    outage_columns = [
        "outage_id",
        "port_id",
        "zone_id",
        "start_at",
        "end_at",
        "latent_reason",
        "simulation_run_id",
    ]
    return pd.DataFrame(outages, columns=outage_columns), reports


def _latent_demand_grid(
    config: VoltEZConfig,
    run_id: str,
    zones: pd.DataFrame,
    latent_zones: pd.DataFrame,
    scenario_lookup: dict[tuple[str, date], str],
) -> pd.DataFrame:
    rng = named_rng(config.project.seed, "demand-counts")
    buckets_per_day = 24 * 60 // config.time.bucket_minutes
    profile = _daily_profile(buckets_per_day)
    zone_multipliers = cast(
        dict[str, float],
        latent_zones.set_index("zone_id")["base_demand_multiplier"].astype(float).to_dict(),
    )
    zone_records = _records(zones)
    neighbor_map = nearest_neighbor_ids(
        zone_records,
        identifier_key="zone_id",
        latitude_key="centroid_latitude",
        longitude_key="centroid_longitude",
    )
    spillover = config.synthetic.demand.spatial_spillover_weight
    blended_multipliers = {
        zone_id: (1 - spillover) * zone_multipliers[zone_id]
        + spillover
        * float(np.mean([zone_multipliers[neighbor] for neighbor in neighbor_map[zone_id]]))
        if neighbor_map[zone_id]
        else zone_multipliers[zone_id]
        for zone_id in zone_multipliers
    }

    rows: list[dict[str, Any]] = []
    for day_offset in range(config.synthetic.days):
        local_date = config.synthetic.start_date + timedelta(days=day_offset)
        weekend_factor = 1.12 if local_date.weekday() >= 5 else 1.0
        day_start = pd.Timestamp(local_date, tz=config.project.timezone)
        for zone_id in zones["zone_id"].astype(str):
            scenario = scenario_lookup[(zone_id, local_date)]
            scenario_factor = SCENARIO_DEMAND_MULTIPLIERS[scenario]
            for bucket_index in range(buckets_per_day):
                bucket_start = day_start + timedelta(
                    minutes=bucket_index * config.time.bucket_minutes
                )
                mean = (
                    config.synthetic.demand.average_requests_per_zone_per_day
                    * profile[bucket_index]
                    * blended_multipliers[zone_id]
                    * weekend_factor
                    * scenario_factor
                )
                n, p = negative_binomial_parameters(
                    float(mean), config.synthetic.demand.negative_binomial_dispersion
                )
                request_count = int(rng.negative_binomial(n, p))
                rows.append(
                    {
                        "zone_id": zone_id,
                        "bucket_start": bucket_start,
                        "latent_mean_requests": float(mean),
                        "latent_request_count": request_count,
                        "scenario": scenario,
                        "simulation_run_id": run_id,
                    }
                )
    return pd.DataFrame(rows)


def _generate_requests(
    config: VoltEZConfig,
    run_id: str,
    latent_grid: pd.DataFrame,
    vehicles: pd.DataFrame,
    vehicle_connectors: pd.DataFrame,
    driver_profiles: pd.DataFrame,
) -> list[dict[str, Any]]:
    rng = named_rng(config.project.seed, "requests")
    vehicle_records = vehicles.merge(
        vehicle_connectors, on=["vehicle_id", "simulation_run_id"]
    ).merge(
        driver_profiles[["user_id", "home_zone_id", "simulation_run_id"]],
        on=["user_id", "simulation_run_id"],
    )
    vehicle_rows = _records(vehicle_records)
    rows: list[dict[str, Any]] = []
    request_index = 0
    for bucket in _records(latent_grid):
        for _ in range(int(bucket["latent_request_count"])):
            vehicle = vehicle_rows[int(rng.integers(len(vehicle_rows)))]
            requested_at = pd.Timestamp(bucket["bucket_start"]) + timedelta(
                seconds=int(rng.integers(0, config.time.bucket_minutes * 60))
            )
            eta_minutes = int(
                rng.choice(config.time.availability_eta_buckets_minutes, p=(0.42, 0.30, 0.20, 0.08))
            )
            current_soc = float(rng.uniform(8, 58))
            reserve_soc = float(rng.uniform(5, min(20, current_soc)))
            target_soc = float(rng.uniform(max(70, current_soc + 15), 95))
            request_id = stable_id(run_id, "request", request_index)
            request_type = str(
                rng.choice(
                    ("nearby_search", "route_planning", "scheduled_search"),
                    p=(0.63, 0.25, 0.12),
                )
            )
            rows.append(
                {
                    "request_id": request_id,
                    "user_id": vehicle["user_id"],
                    "vehicle_id": vehicle["vehicle_id"],
                    "origin_zone_id": vehicle["home_zone_id"],
                    "zone_id": bucket["zone_id"],
                    "requested_at": requested_at,
                    "desired_start_at": requested_at + timedelta(minutes=eta_minutes),
                    "eta_minutes": eta_minutes,
                    "current_soc": round(current_soc, 2),
                    "reserve_soc": round(reserve_soc, 2),
                    "target_soc": round(target_soc, 2),
                    "required_connector_type_id": vehicle["connector_type_id"],
                    "request_type": request_type,
                    "trip_id": stable_id(run_id, "trip", request_id)
                    if request_type == "route_planning"
                    else None,
                    "result_status": "pending",
                    "simulation_run_id": run_id,
                }
            )
            request_index += 1
    return rows


def _known_fault_at_origin(
    port_id: str,
    prediction_origin: pd.Timestamp,
    reports_by_port: dict[str, list[dict[str, Any]]],
) -> bool:
    known = [
        report
        for report in reports_by_port.get(port_id, [])
        if report["ingested_at"] <= prediction_origin < report["expires_at"]
    ]
    if not known:
        return False
    latest = max(known, key=lambda report: report["ingested_at"])
    return str(latest["status"]) in {"faulted", "offline", "maintenance"}


def _booking_conflict(
    port_bookings: list[dict[str, Any]],
    start_at: pd.Timestamp,
    end_at: pd.Timestamp,
    known_at: pd.Timestamp,
) -> bool:
    for booking in port_bookings:
        cancelled_at = booking.get("cancelled_at")
        if cancelled_at is not None and cancelled_at <= known_at:
            continue
        if _intervals_overlap(start_at, end_at, booking["start_at"], booking["end_at"]):
            return True
    return False


def _recommend_and_book(
    config: VoltEZConfig,
    run_id: str,
    requests: list[dict[str, Any]],
    static: dict[str, pd.DataFrame],
    status_reports: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    rng = named_rng(config.project.seed, "recommendations-and-bookings")
    ports = _enriched_ports(static)
    ports_by_zone_connector: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for port in _records(ports):
        ports_by_zone_connector[(str(port["zone_id"]), str(port["connector_type_id"]))].append(port)
    nearest_zones = nearest_neighbor_ids(
        _records(static["zones"]),
        identifier_key="zone_id",
        latitude_key="centroid_latitude",
        longitude_key="centroid_longitude",
    )
    hours_lookup = {
        (str(row["business_id"]), int(row["day_of_week"])): row
        for row in _records(static["business_hours"])
    }
    vehicle_lookup = {str(row["vehicle_id"]): row for row in _records(static["vehicles"])}
    reports_by_port: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for report in status_reports:
        reports_by_port[str(report["port_id"])].append(report)
    bookings_by_port: dict[str, list[dict[str, Any]]] = defaultdict(list)
    impressions: list[dict[str, Any]] = []
    bookings: list[dict[str, Any]] = []
    booking_events: list[dict[str, Any]] = []

    for request in sorted(requests, key=lambda row: row["requested_at"]):
        arrival = request["desired_start_at"]
        vehicle = vehicle_lookup[str(request["vehicle_id"])]
        required_energy = (
            float(vehicle["battery_kwh"])
            * (float(request["target_soc"]) - float(request["current_soc"]))
            / 100
        )
        destination_zone_id = str(request["zone_id"])
        candidate_ports = [
            port
            for candidate_zone_id in [destination_zone_id, *nearest_zones[destination_zone_id]]
            for port in ports_by_zone_connector.get(
                (candidate_zone_id, str(request["required_connector_type_id"])), []
            )
        ]
        scored: list[tuple[float, dict[str, Any], pd.Timestamp]] = []
        for port in candidate_ports:
            max_vehicle_power = (
                float(vehicle["max_ac_kw"])
                if port["charging_type"] == "AC"
                else float(vehicle["max_dc_kw"])
            )
            effective_power = max(1.0, min(float(port["max_power_kw"]), max_vehicle_power))
            duration_minutes = int(
                np.clip(math.ceil((required_energy / effective_power * 60 + 15) / 15) * 15, 30, 180)
            )
            end_at = arrival + timedelta(minutes=duration_minutes)
            if not _is_business_open(str(port["business_id"]), arrival, hours_lookup):
                continue
            if _known_fault_at_origin(
                str(port["port_id"]), request["requested_at"], reports_by_port
            ):
                continue
            if _booking_conflict(
                bookings_by_port[str(port["port_id"])], arrival, end_at, request["requested_at"]
            ):
                continue
            power_score = math.log1p(float(port["max_power_kw"])) / math.log1p(60)
            price_score = 1 - min(float(port["price_per_kwh"]), 35) / 35
            proximity_score = 1.0 if str(port["zone_id"]) == destination_zone_id else 0.65
            score = (
                0.45 * power_score
                + 0.25 * price_score
                + 0.20 * proximity_score
                + 0.10 * float(rng.random())
            )
            scored.append((score, port, end_at))
        scored.sort(key=lambda item: item[0], reverse=True)
        shown = scored[: config.synthetic.behaviour.recommendations_per_request]
        if not shown:
            request["result_status"] = "no_candidate"
            continue

        selected_index: int | None = None
        if rng.random() < config.synthetic.behaviour.selection_probability:
            weights = np.exp(np.array([item[0] for item in shown]) * 3)
            selected_index = int(rng.choice(len(shown), p=weights / weights.sum()))
            request["result_status"] = "served"
        else:
            request["result_status"] = "abandoned"

        selected_booking_id: str | None = None
        if selected_index is not None:
            score, selected_port, end_at = shown[selected_index]
            del score
            booking_index = len(bookings)
            selected_booking_id = stable_id(run_id, "booking", booking_index)
            outcome_draw = float(rng.random())
            if outcome_draw < config.synthetic.behaviour.cancellation_probability:
                planned_outcome = "cancelled"
                gap_minutes = max(1, int((arrival - request["requested_at"]).total_seconds() / 60))
                cancelled_at: pd.Timestamp | None = request["requested_at"] + timedelta(
                    minutes=int(rng.integers(1, gap_minutes + 1))
                )
            elif outcome_draw < (
                config.synthetic.behaviour.cancellation_probability
                + config.synthetic.behaviour.no_show_probability
            ):
                planned_outcome = "no_show"
                cancelled_at = None
            else:
                planned_outcome = "attend"
                cancelled_at = None
            booking = {
                "booking_id": selected_booking_id,
                "user_id": request["user_id"],
                "vehicle_id": request["vehicle_id"],
                "port_id": selected_port["port_id"],
                "parking_space_id": selected_port["parking_space_id"],
                "request_id": request["request_id"],
                "start_at": arrival,
                "end_at": end_at,
                "status": "confirmed",
                "hold_expires_at": pd.NaT,
                "quote_snapshot": json.dumps(
                    {
                        "currency": "INR",
                        "price_per_kwh": float(selected_port["price_per_kwh"]),
                        "price_per_minute": float(selected_port["price_per_minute"]),
                        "booking_fee": float(selected_port["booking_fee"]),
                    },
                    sort_keys=True,
                    separators=(",", ":"),
                ),
                "expected_arrival_at": arrival,
                "created_at": request["requested_at"],
                "confirmed_at": request["requested_at"] + timedelta(seconds=30),
                "cancelled_at": cancelled_at,
                "planned_outcome": planned_outcome,
                "simulation_run_id": run_id,
            }
            bookings.append(booking)
            bookings_by_port[str(selected_port["port_id"])].append(booking)
            booking_events.append(
                {
                    "booking_event_id": stable_id(
                        run_id, "booking-event", f"{selected_booking_id}:0"
                    ),
                    "booking_id": selected_booking_id,
                    "old_status": "pending",
                    "new_status": "confirmed",
                    "actor_type": "system",
                    "metadata": "{}",
                    "created_at": booking["confirmed_at"],
                    "ingested_at": booking["confirmed_at"],
                    "simulation_run_id": run_id,
                }
            )

        for rank, (score, port, _) in enumerate(shown, start=1):
            is_selected = selected_index is not None and rank - 1 == selected_index
            impressions.append(
                {
                    "impression_id": stable_id(
                        run_id, "impression", f"{request['request_id']}:{port['port_id']}"
                    ),
                    "user_id": request["user_id"],
                    "request_id": request["request_id"],
                    "charger_id": port["charger_id"],
                    "port_id": port["port_id"],
                    "rank": rank,
                    "recommendation_score": round(float(score), 6),
                    "shown_at": request["requested_at"] + timedelta(seconds=2),
                    "selected": is_selected,
                    "selected_at": request["requested_at"] + timedelta(seconds=20)
                    if is_selected
                    else pd.NaT,
                    "booking_id": selected_booking_id if is_selected else None,
                    "simulation_run_id": run_id,
                }
            )
    return impressions, bookings, booking_events


def _is_in_outage(
    port_id: str,
    moment: pd.Timestamp,
    outages_by_port: dict[str, list[dict[str, Any]]],
) -> bool:
    return any(
        outage["start_at"] <= moment < outage["end_at"]
        for outage in outages_by_port.get(port_id, [])
    )


def _first_outage_start(
    port_id: str,
    start_at: pd.Timestamp,
    end_at: pd.Timestamp,
    outages_by_port: dict[str, list[dict[str, Any]]],
) -> pd.Timestamp | None:
    starts = [
        pd.Timestamp(outage["start_at"])
        for outage in outages_by_port.get(port_id, [])
        if start_at < outage["start_at"] < end_at
    ]
    return min(starts) if starts else None


def _simulate_sessions(
    config: VoltEZConfig,
    run_id: str,
    bookings: list[dict[str, Any]],
    booking_events: list[dict[str, Any]],
    static: dict[str, pd.DataFrame],
    outages: pd.DataFrame,
    status_reports: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    rng = named_rng(config.project.seed, "sessions")
    report_rng = named_rng(config.project.seed, "user-status-reports")
    outages_by_port: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for outage in _records(outages):
        outages_by_port[str(outage["port_id"])].append(outage)
    port_lookup = {str(row["port_id"]): row for row in _records(_enriched_ports(static))}
    vehicle_lookup = {str(row["vehicle_id"]): row for row in _records(static["vehicles"])}
    sessions_by_port: dict[str, list[dict[str, Any]]] = defaultdict(list)
    sessions: list[dict[str, Any]] = []

    for booking in sorted(bookings, key=lambda row: row["start_at"]):
        booking_id = str(booking["booking_id"])
        if booking["planned_outcome"] == "cancelled":
            booking["status"] = "cancelled"
            booking_events.append(
                {
                    "booking_event_id": stable_id(run_id, "booking-event", f"{booking_id}:1"),
                    "booking_id": booking_id,
                    "old_status": "confirmed",
                    "new_status": "cancelled",
                    "actor_type": "driver",
                    "metadata": "{}",
                    "created_at": booking["cancelled_at"],
                    "ingested_at": booking["cancelled_at"],
                    "simulation_run_id": run_id,
                }
            )
            continue
        if booking["planned_outcome"] == "no_show":
            booking["status"] = "no_show"
            event_time = booking["start_at"] + timedelta(minutes=10)
            booking_events.append(
                {
                    "booking_event_id": stable_id(run_id, "booking-event", f"{booking_id}:1"),
                    "booking_id": booking_id,
                    "old_status": "confirmed",
                    "new_status": "no_show",
                    "actor_type": "system",
                    "metadata": "{}",
                    "created_at": event_time,
                    "ingested_at": event_time,
                    "simulation_run_id": run_id,
                }
            )
            continue

        port_id = str(booking["port_id"])
        arrival = booking["start_at"] + timedelta(minutes=int(rng.integers(-3, 9)))
        blocking_sessions = [
            session
            for session in sessions_by_port[port_id]
            if session["start_at"] <= arrival < session["end_at"]
        ]
        service_ready_at = max(
            [arrival, *(pd.Timestamp(session["end_at"]) for session in blocking_sessions)]
        )
        queue_wait_minutes = (service_ready_at - arrival).total_seconds() / 60
        outage_conflict = _is_in_outage(port_id, arrival, outages_by_port)
        session_id = stable_id(run_id, "session", len(sessions))
        queue_too_long = (
            bool(blocking_sessions)
            and queue_wait_minutes > config.synthetic.behaviour.maximum_queue_wait_minutes
        )
        if outage_conflict or queue_too_long:
            reason = "charger_fault" if outage_conflict else "occupied_overrun"
            booking["status"] = "cancelled"
            booking["cancelled_at"] = arrival
            booking_events.append(
                {
                    "booking_event_id": stable_id(run_id, "booking-event", f"{booking_id}:1"),
                    "booking_id": booking_id,
                    "old_status": "confirmed",
                    "new_status": "cancelled",
                    "actor_type": "system",
                    "metadata": json.dumps({"reason": reason}, sort_keys=True),
                    "created_at": arrival,
                    "ingested_at": arrival,
                    "simulation_run_id": run_id,
                }
            )
            sessions.append(
                {
                    "session_id": session_id,
                    "booking_id": booking_id,
                    "port_id": port_id,
                    "vehicle_id": booking["vehicle_id"],
                    "user_id": booking["user_id"],
                    "arrived_at": arrival,
                    "check_in_at": arrival,
                    "queue_joined_at": arrival,
                    "service_ready_at": service_ready_at if queue_too_long else pd.NaT,
                    "start_at": pd.NaT,
                    "end_at": pd.NaT,
                    "start_soc": pd.NA,
                    "end_soc": pd.NA,
                    "energy_kwh": 0.0,
                    "meter_start_kwh": pd.NA,
                    "meter_end_kwh": pd.NA,
                    "final_amount": 0.0,
                    "status": "failed",
                    "failure_reason": reason,
                    "simulation_run_id": run_id,
                }
            )
            continue

        port = port_lookup[port_id]
        vehicle = vehicle_lookup[str(booking["vehicle_id"])]
        if _is_in_outage(port_id, service_ready_at, outages_by_port):
            booking["status"] = "cancelled"
            booking["cancelled_at"] = service_ready_at
            booking_events.append(
                {
                    "booking_event_id": stable_id(run_id, "booking-event", f"{booking_id}:1"),
                    "booking_id": booking_id,
                    "old_status": "confirmed",
                    "new_status": "cancelled",
                    "actor_type": "system",
                    "metadata": json.dumps({"reason": "charger_fault"}, sort_keys=True),
                    "created_at": service_ready_at,
                    "ingested_at": service_ready_at,
                    "simulation_run_id": run_id,
                }
            )
            sessions.append(
                {
                    "session_id": session_id,
                    "booking_id": booking_id,
                    "port_id": port_id,
                    "vehicle_id": booking["vehicle_id"],
                    "user_id": booking["user_id"],
                    "arrived_at": arrival,
                    "check_in_at": arrival,
                    "queue_joined_at": arrival,
                    "service_ready_at": service_ready_at,
                    "start_at": pd.NaT,
                    "end_at": pd.NaT,
                    "start_soc": pd.NA,
                    "end_soc": pd.NA,
                    "energy_kwh": 0.0,
                    "meter_start_kwh": pd.NA,
                    "meter_end_kwh": pd.NA,
                    "final_amount": 0.0,
                    "status": "failed",
                    "failure_reason": "charger_fault",
                    "simulation_run_id": run_id,
                }
            )
            continue

        start = service_ready_at + timedelta(minutes=int(rng.integers(1, 8)))
        reserved_minutes = int((booking["end_at"] - booking["start_at"]).total_seconds() / 60)
        planned_minutes = int(
            np.clip(
                reserved_minutes
                * rng.lognormal(
                    -0.08,
                    config.synthetic.behaviour.session_duration_log_sigma,
                ),
                20,
                210,
            )
        )
        planned_end = start + timedelta(minutes=planned_minutes)
        fault_at = _first_outage_start(port_id, start, planned_end, outages_by_port)
        end = fault_at if fault_at is not None else planned_end
        actual_minutes = max(1, int((end - start).total_seconds() / 60))
        max_vehicle_power = (
            float(vehicle["max_ac_kw"])
            if port["charging_type"] == "AC"
            else float(vehicle["max_dc_kw"])
        )
        effective_power = max(1.0, min(float(port["max_power_kw"]), max_vehicle_power))
        energy_kwh = min(
            float(vehicle["battery_kwh"]) * 0.9,
            effective_power * actual_minutes / 60 * float(rng.uniform(0.82, 0.94)),
        )
        start_soc = float(rng.uniform(8, 58))
        end_soc = min(100.0, start_soc + energy_kwh / float(vehicle["battery_kwh"]) * 100)
        meter_start_kwh = float(rng.uniform(5_000, 50_000))
        meter_end_kwh = meter_start_kwh + energy_kwh
        final_amount = (
            energy_kwh * float(port["price_per_kwh"])
            + actual_minutes * float(port["price_per_minute"])
            + float(port["booking_fee"])
        )
        session = {
            "session_id": session_id,
            "booking_id": booking_id,
            "port_id": port_id,
            "vehicle_id": booking["vehicle_id"],
            "user_id": booking["user_id"],
            "arrived_at": arrival,
            "check_in_at": arrival,
            "queue_joined_at": arrival,
            "service_ready_at": service_ready_at,
            "start_at": start,
            "end_at": end,
            "start_soc": round(start_soc, 2),
            "end_soc": round(end_soc, 2),
            "energy_kwh": round(energy_kwh, 3),
            "meter_start_kwh": round(meter_start_kwh, 3),
            "meter_end_kwh": round(meter_end_kwh, 3),
            "final_amount": round(final_amount, 2),
            "status": "failed" if fault_at is not None else "completed",
            "failure_reason": "charger_fault_mid_session" if fault_at is not None else None,
            "simulation_run_id": run_id,
        }
        sessions.append(session)
        sessions_by_port[port_id].append(session)
        booking["status"] = "failed" if fault_at is not None else "completed"
        final_booking_state = "failed" if fault_at is not None else "completed"
        for sequence, (old_status, new_status, event_time) in enumerate(
            (
                ("confirmed", "checked_in", arrival),
                ("checked_in", "charging", start),
                ("charging", final_booking_state, end),
            ),
            start=1,
        ):
            booking_events.append(
                {
                    "booking_event_id": stable_id(
                        run_id, "booking-event", f"{booking_id}:{sequence}"
                    ),
                    "booking_id": booking_id,
                    "old_status": old_status,
                    "new_status": new_status,
                    "actor_type": "system",
                    "metadata": "{}",
                    "created_at": event_time,
                    "ingested_at": event_time,
                    "simulation_run_id": run_id,
                }
            )
        session_status_events = [
            ("start", start, "occupied", "driver_check_in"),
            (
                "end",
                end,
                "faulted" if fault_at is not None else "available",
                "system" if fault_at is not None else "driver_check_out",
            ),
        ]
        for marker, event_time, status, source in session_status_events:
            status_reports.append(
                {
                    "status_event_id": stable_id(
                        run_id, "status", f"session:{session_id}:{marker}"
                    ),
                    "charger_id": port["charger_id"],
                    "port_id": port_id,
                    "status": status,
                    "source": source,
                    "confidence": 0.98,
                    "observed_at": event_time,
                    "ingested_at": event_time + timedelta(seconds=30),
                    "expires_at": event_time
                    + timedelta(minutes=config.synthetic.availability.median_status_ttl_minutes),
                    "evidence_type": (
                        "qr_check_in"
                        if marker == "start"
                        else "fault_diagnostic"
                        if fault_at is not None
                        else "qr_check_out"
                    ),
                    "simulation_run_id": run_id,
                }
            )
        if fault_at is not None:
            continue
        user_report_is_wrong = bool(
            report_rng.random() < config.synthetic.availability.user_report_error_probability
        )
        user_report_time = start + timedelta(minutes=int(report_rng.integers(2, 10)))
        status_reports.append(
            {
                "status_event_id": stable_id(
                    run_id, "status", f"session:{session_id}:voluntary-report"
                ),
                "charger_id": port["charger_id"],
                "port_id": port_id,
                "status": "available" if user_report_is_wrong else "occupied",
                "source": "driver_report",
                "confidence": 0.45 if user_report_is_wrong else 0.70,
                "observed_at": user_report_time,
                "ingested_at": user_report_time + timedelta(minutes=1),
                "expires_at": user_report_time
                + timedelta(minutes=config.synthetic.availability.median_status_ttl_minutes),
                "evidence_type": "gps_user_report",
                "simulation_run_id": run_id,
            }
        )
    return sessions


def _generate_trips_and_options(
    run_id: str,
    requests: list[dict[str, Any]],
    impressions: list[dict[str, Any]],
    static: dict[str, pd.DataFrame],
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Create journey rows and charger-level route options for route-planning requests."""

    zone_lookup = {str(row["zone_id"]): row for row in _records(static["zones"])}
    vehicle_lookup = {str(row["vehicle_id"]): row for row in _records(static["vehicles"])}
    port_lookup = {str(row["port_id"]): row for row in _records(_enriched_ports(static))}
    impressions_by_request: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for impression in impressions:
        impressions_by_request[str(impression["request_id"])].append(impression)

    trips: list[dict[str, Any]] = []
    options: list[dict[str, Any]] = []
    for request in requests:
        if not request.get("trip_id"):
            continue
        origin = zone_lookup[str(request["origin_zone_id"])]
        destination = zone_lookup[str(request["zone_id"])]
        direct_distance = haversine_km(
            float(origin["centroid_latitude"]),
            float(origin["centroid_longitude"]),
            float(destination["centroid_latitude"]),
            float(destination["centroid_longitude"]),
        )
        road_distance = max(1.0, direct_distance * 1.25)
        trips.append(
            {
                "trip_id": request["trip_id"],
                "user_id": request["user_id"],
                "vehicle_id": request["vehicle_id"],
                "start_latitude": origin["centroid_latitude"],
                "start_longitude": origin["centroid_longitude"],
                "destination_latitude": destination["centroid_latitude"],
                "destination_longitude": destination["centroid_longitude"],
                "started_at": pd.NaT,
                "ended_at": pd.NaT,
                "distance_km": round(road_distance, 3),
                "status": "planned",
                "simulation_run_id": run_id,
            }
        )

        vehicle = vehicle_lookup[str(request["vehicle_id"])]
        required_energy = (
            float(vehicle["battery_kwh"])
            * (float(request["target_soc"]) - float(request["current_soc"]))
            / 100
        )
        seen_chargers: set[str] = set()
        for impression in sorted(
            impressions_by_request[str(request["request_id"])],
            key=lambda row: int(row["rank"]),
        ):
            port = port_lookup[str(impression["port_id"])]
            charger_id = str(port["charger_id"])
            if charger_id in seen_chargers:
                continue
            seen_chargers.add(charger_id)
            via_distance = 1.25 * (
                haversine_km(
                    float(origin["centroid_latitude"]),
                    float(origin["centroid_longitude"]),
                    float(port["latitude"]),
                    float(port["longitude"]),
                )
                + haversine_km(
                    float(port["latitude"]),
                    float(port["longitude"]),
                    float(destination["centroid_latitude"]),
                    float(destination["centroid_longitude"]),
                )
            )
            max_vehicle_power = (
                float(vehicle["max_ac_kw"])
                if port["charging_type"] == "AC"
                else float(vehicle["max_dc_kw"])
            )
            effective_power = max(1.0, min(float(port["max_power_kw"]), max_vehicle_power))
            estimated_charge_minutes = int(
                np.clip(math.ceil(required_energy / effective_power * 60), 15, 180)
            )
            estimated_total_cost = (
                required_energy * float(port["price_per_kwh"])
                + estimated_charge_minutes * float(port["price_per_minute"])
                + float(port["booking_fee"])
            )
            options.append(
                {
                    "trip_id": request["trip_id"],
                    "charger_id": charger_id,
                    "rank": len(seen_chargers),
                    "estimated_detour_km": round(max(0.0, via_distance - road_distance), 3),
                    "estimated_arrival_at": request["desired_start_at"],
                    "estimated_charge_time_min": estimated_charge_minutes,
                    "estimated_total_cost": round(estimated_total_cost, 2),
                    "simulation_run_id": run_id,
                }
            )
    trip_columns = [
        "trip_id",
        "user_id",
        "vehicle_id",
        "start_latitude",
        "start_longitude",
        "destination_latitude",
        "destination_longitude",
        "started_at",
        "ended_at",
        "distance_km",
        "status",
        "simulation_run_id",
    ]
    option_columns = [
        "trip_id",
        "charger_id",
        "rank",
        "estimated_detour_km",
        "estimated_arrival_at",
        "estimated_charge_time_min",
        "estimated_total_cost",
        "simulation_run_id",
    ]
    return pd.DataFrame(trips, columns=trip_columns), pd.DataFrame(options, columns=option_columns)


def _verified_session_availability(
    target: pd.Timestamp,
    session: dict[str, Any],
    tolerance_minutes: int,
) -> tuple[str, str, pd.Timestamp, float] | None:
    """Convert trustworthy session evidence into availability within the product tolerance."""

    tolerance_end = target + timedelta(minutes=tolerance_minutes)
    arrived_at = session.get("arrived_at")
    if arrived_at is None or pd.isna(arrived_at):
        raise ValueError("a session availability outcome requires actual arrival time")
    if pd.Timestamp(arrived_at) > tolerance_end:
        # A late driver cannot establish whether the port was usable near the promised ETA.
        return None

    start_at = session.get("start_at")
    if start_at is not None and not pd.isna(start_at):
        service_ready_at = session.get("service_ready_at")
        if service_ready_at is None or pd.isna(service_ready_at):
            raise ValueError("a started session must record when the port became service-ready")
        within_tolerance = pd.Timestamp(service_ready_at) <= tolerance_end
        return (
            "available" if within_tolerance else "unavailable",
            (
                "verified_service_ready_within_tolerance"
                if within_tolerance
                else "verified_service_ready_after_tolerance"
            ),
            pd.Timestamp(start_at),
            0.99,
        )

    if session.get("status") == "failed" and session.get("failure_reason") in {
        "charger_fault",
        "occupied_overrun",
    }:
        check_in_at = session.get("check_in_at")
        if check_in_at is None or pd.isna(check_in_at):
            raise ValueError("a verified pre-service failure must record check-in time")
        return (
            "unavailable",
            "verified_check_in_failure",
            pd.Timestamp(check_in_at),
            0.98,
        )

    return None


def _availability_observations(
    config: VoltEZConfig,
    run_id: str,
    requests: list[dict[str, Any]],
    impressions: list[dict[str, Any]],
    bookings: list[dict[str, Any]],
    sessions: list[dict[str, Any]],
    outages: pd.DataFrame,
    static: dict[str, pd.DataFrame],
    status_reports: list[dict[str, Any]],
    snapshot_id: str,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    request_lookup = {str(row["request_id"]): row for row in requests}
    booking_lookup = {str(row["booking_id"]): row for row in bookings}
    port_lookup = {str(row["port_id"]): row for row in _records(_enriched_ports(static))}
    hours_lookup = {
        (str(row["business_id"]), int(row["day_of_week"])): row
        for row in _records(static["business_hours"])
    }
    outages_by_port: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for outage in _records(outages):
        outages_by_port[str(outage["port_id"])].append(outage)
    bookings_by_port: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for booking in bookings:
        bookings_by_port[str(booking["port_id"])].append(booking)
    sessions_by_port: dict[str, list[dict[str, Any]]] = defaultdict(list)
    sessions_by_booking: dict[str, dict[str, Any]] = {}
    for session in sessions:
        sessions_by_port[str(session["port_id"])].append(session)
        sessions_by_booking[str(session["booking_id"])] = session
    reports_by_port: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for report in status_reports:
        reports_by_port[str(report["port_id"])].append(report)

    observations: list[dict[str, Any]] = []
    latent_rows: list[dict[str, Any]] = []
    for impression in impressions:
        request = request_lookup[str(impression["request_id"])]
        port_id = str(impression["port_id"])
        port = port_lookup[port_id]
        target = request["desired_start_at"]
        own_booking_id = impression.get("booking_id")
        open_at_target = _is_business_open(str(port["business_id"]), target, hours_lookup)
        outage_at_target = _is_in_outage(port_id, target, outages_by_port)
        conflicting_session = any(
            not pd.isna(session["start_at"])
            and session["booking_id"] != own_booking_id
            and session["start_at"] <= target < session["end_at"]
            for session in sessions_by_port[port_id]
        )
        conflicting_booking = any(
            booking["booking_id"] != own_booking_id
            and booking["status"] not in {"cancelled"}
            and _intervals_overlap(
                target,
                target + timedelta(minutes=1),
                booking["start_at"],
                booking["end_at"],
            )
            for booking in bookings_by_port[port_id]
        )
        latent_available_at_target = bool(
            open_at_target
            and not outage_at_target
            and not conflicting_session
            and not conflicting_booking
        )
        latent_available_within_tolerance = latent_available_at_target
        label = "unknown"
        label_source: str | None = None
        label_observed_at: pd.Timestamp | None = None
        label_confidence = 0.0
        censoring_reason: str | None = "unobserved_candidate"
        if own_booking_id:
            own_booking = booking_lookup[str(own_booking_id)]
            selected_session = sessions_by_booking.get(str(own_booking_id))
            if selected_session:
                verified_outcome = _verified_session_availability(
                    target,
                    selected_session,
                    config.synthetic.availability.availability_tolerance_minutes,
                )
                if verified_outcome is not None:
                    label, label_source, label_observed_at, label_confidence = verified_outcome
                    latent_available_within_tolerance = label == "available"
                    censoring_reason = None
                else:
                    censoring_reason = "outcome_not_aligned_to_target_time"
            elif own_booking["status"] == "no_show":
                censoring_reason = "driver_no_show"
            elif own_booking["status"] == "cancelled":
                censoring_reason = "booking_cancelled"
        else:
            strong_reports = [
                report
                for report in reports_by_port[port_id]
                if report["source"] in {"driver_check_in", "driver_check_out", "support", "system"}
                and abs((report["observed_at"] - target).total_seconds()) <= 15 * 60
            ]
            if strong_reports:
                strongest = min(
                    strong_reports,
                    key=lambda report: abs((report["observed_at"] - target).total_seconds()),
                )
                label = "available" if latent_available_at_target else "unavailable"
                label_source = "independent_status_evidence"
                label_observed_at = strongest["ingested_at"]
                label_confidence = float(strongest["confidence"])
                censoring_reason = None

        booking_state = (
            "conflicting_booking"
            if conflicting_booking
            else "own_booking"
            if own_booking_id
            else "none"
        )
        port_status = (
            "faulted"
            if outage_at_target
            else "occupied"
            if conflicting_session or conflicting_booking
            else "available"
            if open_at_target
            else "offline"
        )

        observation_id = stable_id(run_id, "availability-observation", impression["impression_id"])
        observations.append(
            {
                "observation_id": observation_id,
                "request_id": request["request_id"],
                "port_id": port_id,
                "prediction_origin": request["requested_at"],
                "target_arrival_at": target,
                "observed_at": target,
                "feature_cutoff": request["requested_at"],
                "eligible_at_origin": True,
                "label": label,
                "label_source": label_source,
                "confidence": label_confidence,
                "booking_state": booking_state,
                "port_status": port_status,
                "label_observed_at": label_observed_at,
                "censoring_reason": censoring_reason,
                "source_snapshot_id": snapshot_id,
                "simulation_run_id": run_id,
            }
        )
        latent_rows.append(
            {
                "observation_id": observation_id,
                "latent_available": latent_available_within_tolerance,
                "latent_available_at_target": latent_available_at_target,
                "availability_tolerance_minutes": (
                    config.synthetic.availability.availability_tolerance_minutes
                ),
                "open_at_target": open_at_target,
                "outage_at_target": outage_at_target,
                "conflicting_session": conflicting_session,
                "conflicting_booking": conflicting_booking,
                "simulation_run_id": run_id,
            }
        )
    return pd.DataFrame(observations), pd.DataFrame(latent_rows)


def _service_observations(
    run_id: str,
    snapshot_id: str,
    requests: list[dict[str, Any]],
    bookings: list[dict[str, Any]],
    sessions: list[dict[str, Any]],
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Create observed labels for queue waiting and intrinsic charger reliability."""

    request_lookup = {str(row["request_id"]): row for row in requests}
    booking_lookup = {str(row["booking_id"]): row for row in bookings}
    waiting_rows: list[dict[str, Any]] = []
    reliability_rows: list[dict[str, Any]] = []
    for session in sessions:
        booking = booking_lookup[str(session["booking_id"])]
        request = request_lookup[str(booking["request_id"])]
        origin = pd.Timestamp(request["requested_at"])
        arrival = pd.Timestamp(session["check_in_at"])
        ready_at = session.get("service_ready_at")
        ready_timestamp = (
            pd.Timestamp(ready_at) if ready_at is not None and not pd.isna(ready_at) else None
        )
        ready_known = ready_timestamp is not None
        wait_minutes = (
            max(0.0, (ready_timestamp - arrival).total_seconds() / 60)
            if ready_timestamp is not None
            else np.nan
        )
        waiting_rows.append(
            {
                "waiting_observation_id": stable_id(
                    run_id, "waiting-observation", session["session_id"]
                ),
                "request_id": request["request_id"],
                "booking_id": booking["booking_id"],
                "session_id": session["session_id"],
                "port_id": session["port_id"],
                "prediction_origin": origin,
                "feature_cutoff": origin,
                "target_arrival_at": request["desired_start_at"],
                "actual_arrival_at": arrival,
                "label_wait_minutes": round(wait_minutes, 3) if ready_known else np.nan,
                "label_known": int(ready_known),
                "label_source": (
                    "prior_session_checkout"
                    if ready_known and wait_minutes > 0
                    else "verified_arrival"
                    if ready_known
                    else None
                ),
                "label_observed_at": ready_timestamp if ready_timestamp is not None else pd.NaT,
                "outcome": (
                    "charging_started"
                    if not pd.isna(session["start_at"])
                    else "queue_abandoned"
                    if session["failure_reason"] == "occupied_overrun"
                    else "charger_fault"
                ),
                "source_snapshot_id": snapshot_id,
                "simulation_run_id": run_id,
            }
        )

        failure_reason = str(session.get("failure_reason") or "")
        if session["status"] == "completed":
            reliability_label = "reliable"
            reliability_source = "completed_session"
            reliability_observed_at = session["end_at"]
        elif failure_reason.startswith("charger_fault"):
            reliability_label = "unreliable"
            reliability_source = "verified_charger_failure"
            reliability_observed_at = (
                session["end_at"] if not pd.isna(session["end_at"]) else session["check_in_at"]
            )
        else:
            reliability_label = "unknown"
            reliability_source = None
            reliability_observed_at = session["check_in_at"]
        reliability_rows.append(
            {
                "reliability_observation_id": stable_id(
                    run_id, "reliability-observation", session["session_id"]
                ),
                "request_id": request["request_id"],
                "booking_id": booking["booking_id"],
                "session_id": session["session_id"],
                "port_id": session["port_id"],
                "prediction_origin": origin,
                "feature_cutoff": origin,
                "target_arrival_at": request["desired_start_at"],
                "label": reliability_label,
                "label_known": int(reliability_label != "unknown"),
                "label_source": reliability_source,
                "label_observed_at": reliability_observed_at,
                "failure_reason": session.get("failure_reason"),
                "source_snapshot_id": snapshot_id,
                "simulation_run_id": run_id,
            }
        )
    return pd.DataFrame(waiting_rows), pd.DataFrame(reliability_rows)


def _interval_counts(
    intervals: list[dict[str, Any]],
    zone_by_port: dict[str, str],
    start_key: str,
    end_key: str,
    bucket_minutes: int,
) -> pd.DataFrame:
    counts: dict[tuple[str, pd.Timestamp], set[str]] = defaultdict(set)
    for interval in intervals:
        start = interval.get(start_key)
        end = interval.get(end_key)
        if start is None or end is None or pd.isna(start) or pd.isna(end):
            continue
        bucket = start.floor(f"{bucket_minutes}min")
        while bucket < end:
            counts[(zone_by_port[str(interval["port_id"])], bucket)].add(str(interval["port_id"]))
            bucket += timedelta(minutes=bucket_minutes)
    return pd.DataFrame(
        [
            {"zone_id": zone_id, "bucket_start": bucket, "busy_port_count": len(port_ids)}
            for (zone_id, bucket), port_ids in counts.items()
        ]
    )


def _demand_buckets(
    config: VoltEZConfig,
    run_id: str,
    latent_grid: pd.DataFrame,
    requests: list[dict[str, Any]],
    bookings: list[dict[str, Any]],
    sessions: list[dict[str, Any]],
    outages: pd.DataFrame,
    ports: pd.DataFrame,
    snapshot_id: str,
) -> pd.DataFrame:
    bucket_minutes = config.time.bucket_minutes
    buckets = latent_grid[["zone_id", "bucket_start"]].copy()
    request_frame = pd.DataFrame(requests)
    request_frame["bucket_start"] = request_frame["requested_at"].dt.floor(f"{bucket_minutes}min")
    request_counts = request_frame.groupby(["zone_id", "bucket_start"], as_index=False).agg(
        search_count=(
            "request_type",
            lambda values: int(values.isin({"nearby_search", "route_planning"}).sum()),
        ),
        request_count=("request_id", "size"),
        served_request_count=("result_status", lambda values: int((values == "served").sum())),
        no_candidate_count=(
            "result_status",
            lambda values: int((values == "no_candidate").sum()),
        ),
        unserved_count=(
            "result_status",
            lambda values: int(values.isin({"no_candidate", "abandoned"}).sum()),
        ),
    )
    buckets = buckets.merge(request_counts, on=["zone_id", "bucket_start"], how="left")

    port_zone = cast(dict[str, str], ports.set_index("port_id")["zone_id"].astype(str).to_dict())
    if bookings:
        booking_frame = pd.DataFrame(bookings)
        booking_frame["zone_id"] = booking_frame["port_id"].map(port_zone)
        booking_frame["bucket_start"] = booking_frame["start_at"].dt.floor(f"{bucket_minutes}min")
        booking_counts = (
            booking_frame.groupby(["zone_id", "bucket_start"], as_index=False)
            .size()
            .rename(columns={"size": "booking_count"})
        )
        buckets = buckets.merge(booking_counts, on=["zone_id", "bucket_start"], how="left")
    else:
        buckets["booking_count"] = 0

    started_sessions = [session for session in sessions if not pd.isna(session["start_at"])]
    if started_sessions:
        session_frame = pd.DataFrame(started_sessions)
        session_frame["zone_id"] = session_frame["port_id"].map(port_zone)
        session_frame["bucket_start"] = session_frame["start_at"].dt.floor(f"{bucket_minutes}min")
        session_counts = (
            session_frame.groupby(["zone_id", "bucket_start"], as_index=False)
            .size()
            .rename(columns={"size": "session_count"})
        )
        buckets = buckets.merge(session_counts, on=["zone_id", "bucket_start"], how="left")
    else:
        buckets["session_count"] = 0

    listed = (
        ports.groupby("zone_id", as_index=False)
        .size()
        .rename(columns={"size": "compatible_ports_listed"})
    )
    buckets = buckets.merge(listed, on="zone_id", how="left")
    busy_intervals = [
        {
            "port_id": outage["port_id"],
            "busy_start": outage["start_at"],
            "busy_end": outage["end_at"],
        }
        for outage in _records(outages)
    ] + [
        {
            "port_id": session["port_id"],
            "busy_start": session["start_at"],
            "busy_end": session["end_at"],
        }
        for session in started_sessions
    ]
    busy = _interval_counts(busy_intervals, port_zone, "busy_start", "busy_end", bucket_minutes)
    if not busy.empty:
        buckets = buckets.merge(busy, on=["zone_id", "bucket_start"], how="left")
    else:
        buckets["busy_port_count"] = 0
    buckets["compatible_ports_available"] = (
        buckets["compatible_ports_listed"] - buckets["busy_port_count"].fillna(0)
    ).clip(lower=0)
    buckets["occupancy_rate"] = (
        buckets["busy_port_count"].fillna(0) / buckets["compatible_ports_listed"].clip(lower=1)
    ).clip(lower=0, upper=1)
    buckets = buckets.drop(columns="busy_port_count")
    buckets = buckets.merge(
        listed.rename(columns={"compatible_ports_listed": "listed_copy"}),
        on="zone_id",
        how="left",
    )
    buckets = buckets.drop(columns="listed_copy")
    count_columns = [
        "search_count",
        "request_count",
        "served_request_count",
        "no_candidate_count",
        "unserved_count",
        "booking_count",
        "session_count",
    ]
    for column in count_columns:
        buckets[column] = buckets[column].fillna(0).astype("int64")
    buckets["compatible_ports_listed"] = buckets["compatible_ports_listed"].astype("int64")
    buckets["compatible_ports_available"] = buckets["compatible_ports_available"].astype("int64")
    buckets["bucket_minutes"] = bucket_minutes
    buckets["source_snapshot_id"] = snapshot_id
    buckets["simulation_run_id"] = run_id
    return buckets[
        [
            "zone_id",
            "bucket_start",
            "bucket_minutes",
            "search_count",
            "request_count",
            "served_request_count",
            "no_candidate_count",
            "unserved_count",
            "booking_count",
            "session_count",
            "occupancy_rate",
            "compatible_ports_listed",
            "compatible_ports_available",
            "source_snapshot_id",
            "simulation_run_id",
        ]
    ]


def generate_event_tables(
    config: VoltEZConfig,
    run_id: str,
    snapshot_id: str,
    static: dict[str, pd.DataFrame],
) -> dict[str, pd.DataFrame]:
    """Generate all mutable events in causal order and their first analytics projections."""

    context_events, scenario_lookup = _scenario_tables(config, run_id, static["zones"])
    outages, status_reports = _generate_outages_and_initial_reports(
        config,
        run_id,
        _enriched_ports(static),
        static["qa_latent_port_profiles"],
        scenario_lookup,
    )
    latent_grid = _latent_demand_grid(
        config, run_id, static["zones"], static["qa_latent_zones"], scenario_lookup
    )
    requests = _generate_requests(
        config,
        run_id,
        latent_grid,
        static["vehicles"],
        static["vehicle_connectors"],
        static["qa_latent_driver_profiles"],
    )
    impressions, bookings, booking_events = _recommend_and_book(
        config, run_id, requests, static, status_reports
    )
    sessions = _simulate_sessions(
        config, run_id, bookings, booking_events, static, outages, status_reports
    )
    trips, trip_charger_options = _generate_trips_and_options(run_id, requests, impressions, static)
    route_snapshots, trips, trip_charger_options = generate_route_snapshots(
        config,
        run_id,
        requests,
        trips,
        trip_charger_options,
        static["chargers"],
        static["vehicles"],
        static["zones"],
        scenario_lookup,
    )
    availability_observations, latent_availability = _availability_observations(
        config,
        run_id,
        requests,
        impressions,
        bookings,
        sessions,
        outages,
        static,
        status_reports,
        snapshot_id,
    )
    waiting_time_observations, reliability_observations = _service_observations(
        run_id,
        snapshot_id,
        requests,
        bookings,
        sessions,
    )
    demand_buckets = _demand_buckets(
        config,
        run_id,
        latent_grid,
        requests,
        bookings,
        sessions,
        outages,
        _enriched_ports(static),
        snapshot_id,
    )

    public_booking_columns = [
        "booking_id",
        "user_id",
        "vehicle_id",
        "port_id",
        "parking_space_id",
        "request_id",
        "start_at",
        "end_at",
        "status",
        "hold_expires_at",
        "quote_snapshot",
        "expected_arrival_at",
        "created_at",
        "confirmed_at",
        "cancelled_at",
        "simulation_run_id",
    ]
    bookings_frame = (
        pd.DataFrame(bookings)[public_booking_columns]
        if bookings
        else pd.DataFrame(columns=public_booking_columns)
    )
    for timestamp_column in (
        "start_at",
        "end_at",
        "hold_expires_at",
        "expected_arrival_at",
        "created_at",
        "confirmed_at",
        "cancelled_at",
    ):
        bookings_frame[timestamp_column] = pd.to_datetime(
            bookings_frame[timestamp_column], utc=True
        ).dt.tz_convert(config.project.timezone)
    tables = {
        "context_events": context_events,
        "charging_requests": pd.DataFrame(requests),
        "trips": trips,
        "route_snapshots": route_snapshots,
        "trip_charger_options": trip_charger_options,
        "recommendation_impressions": pd.DataFrame(impressions),
        "bookings": bookings_frame,
        "booking_events": pd.DataFrame(booking_events),
        "charging_sessions": pd.DataFrame(sessions),
        "charger_status_events": pd.DataFrame(status_reports),
        "demand_buckets": demand_buckets,
        "availability_observations": availability_observations,
        "waiting_time_observations": waiting_time_observations,
        "reliability_observations": reliability_observations,
        "qa_latent_demand": latent_grid,
        "qa_latent_outages": outages,
        "qa_latent_availability": latent_availability,
    }
    return {name: frame.reset_index(drop=True) for name, frame in tables.items()}
