"""Fail-fast invariants for generated VoltEZ datasets."""

from __future__ import annotations

import math
from typing import Any

import pandas as pd

from voltez_ml.config import VoltEZConfig


class DatasetValidationError(ValueError):
    """Raised when synthetic output violates an application or ML invariant."""


def estimate_planned_rows(config: VoltEZConfig) -> int:
    """Estimate a conservative row plan before allocating the full simulation."""

    settings = config.synthetic
    buckets_per_day = 24 * 60 // config.time.bucket_minutes
    grid_rows = settings.zone_count * settings.days * buckets_per_day
    maximum_ports = settings.charger_count * settings.supply.maximum_ports_per_charger
    expected_requests_with_headroom = math.ceil(
        settings.demand.average_requests_per_zone_per_day
        * settings.zone_count
        * settings.days
        * 2.5
    )
    static_rows = (
        settings.zone_count * 2
        + settings.business_count * 8
        + settings.charger_count
        + maximum_ports * (2 + settings.days)
        + settings.driver_count * 3
        + 5
    )
    per_request_rows = 8 + settings.behaviour.recommendations_per_request * 3
    event_rows = grid_rows * 2 + expected_requests_with_headroom * per_request_rows
    status_headroom = maximum_ports * (1 + settings.days * 2)
    return static_rows + event_rows + status_headroom


def _require_foreign_keys(
    child: pd.DataFrame,
    child_column: str,
    parent: pd.DataFrame,
    parent_column: str,
) -> None:
    missing = set(child[child_column].dropna()) - set(parent[parent_column].dropna())
    if missing:
        examples = sorted(str(value) for value in missing)[:3]
        raise DatasetValidationError(
            f"{child_column} contains values missing from {parent_column}: {examples}"
        )


def _validate_booking_overlaps(bookings: pd.DataFrame, resource_column: str) -> None:
    active = bookings[~bookings["status"].isin(["cancelled"])]
    for resource_id, group in active.sort_values("start_at").groupby(resource_column):
        prior_end: pd.Timestamp | None = None
        for row in group[["start_at", "end_at"]].to_dict("records"):
            start_at = pd.Timestamp(row["start_at"])
            end_at = pd.Timestamp(row["end_at"])
            if prior_end is not None and start_at < prior_end:
                raise DatasetValidationError(
                    f"active bookings overlap on {resource_column} {resource_id}"
                )
            prior_end = end_at


def _validate_booking_state_events(events: pd.DataFrame) -> None:
    allowed = {
        ("pending", "confirmed"),
        ("confirmed", "cancelled"),
        ("confirmed", "no_show"),
        ("confirmed", "checked_in"),
        ("checked_in", "charging"),
        ("charging", "completed"),
    }
    transitions = set(zip(events["old_status"], events["new_status"], strict=False))
    invalid = transitions - allowed
    if invalid:
        raise DatasetValidationError(f"invalid booking transitions: {sorted(invalid)}")


def validate_dataset(config: VoltEZConfig, tables: dict[str, pd.DataFrame]) -> None:
    """Validate relational, temporal, leakage, and resource-safety guarantees."""

    required_tables = {
        "zones",
        "businesses",
        "chargers",
        "charger_ports",
        "parking_spaces",
        "vehicles",
        "vehicle_connectors",
        "charging_requests",
        "recommendation_impressions",
        "bookings",
        "booking_events",
        "charging_sessions",
        "charger_status_events",
        "demand_buckets",
        "availability_observations",
        "qa_latent_demand",
        "qa_latent_outages",
        "qa_latent_availability",
    }
    missing_tables = required_tables - set(tables)
    if missing_tables:
        raise DatasetValidationError(f"required tables missing: {sorted(missing_tables)}")

    total_rows = sum(len(frame) for frame in tables.values())
    if total_rows > config.synthetic.safeguards.maximum_generated_rows:
        raise DatasetValidationError(
            f"generated {total_rows} rows, above safety limit "
            f"{config.synthetic.safeguards.maximum_generated_rows}"
        )

    for name, frame in tables.items():
        if not name.startswith("qa_latent_"):
            forbidden = [column for column in frame.columns if column.startswith("latent_")]
            if forbidden:
                raise DatasetValidationError(
                    f"latent QA fields leaked into public table {name}: {forbidden}"
                )

    _require_foreign_keys(tables["businesses"], "zone_id", tables["zones"], "zone_id")
    _require_foreign_keys(tables["chargers"], "business_id", tables["businesses"], "business_id")
    _require_foreign_keys(tables["charger_ports"], "charger_id", tables["chargers"], "charger_id")
    _require_foreign_keys(
        tables["charger_ports"],
        "parking_space_id",
        tables["parking_spaces"],
        "parking_space_id",
    )
    _require_foreign_keys(
        tables["charging_requests"], "vehicle_id", tables["vehicles"], "vehicle_id"
    )
    _require_foreign_keys(
        tables["recommendation_impressions"],
        "request_id",
        tables["charging_requests"],
        "request_id",
    )
    _require_foreign_keys(
        tables["recommendation_impressions"], "port_id", tables["charger_ports"], "port_id"
    )
    if not tables["bookings"].empty:
        _require_foreign_keys(
            tables["bookings"], "request_id", tables["charging_requests"], "request_id"
        )
        _require_foreign_keys(tables["bookings"], "port_id", tables["charger_ports"], "port_id")
        _require_foreign_keys(
            tables["bookings"],
            "parking_space_id",
            tables["parking_spaces"],
            "parking_space_id",
        )
        if bool((tables["bookings"]["end_at"] <= tables["bookings"]["start_at"]).any()):
            raise DatasetValidationError("booking end_at must be later than start_at")
        _validate_booking_overlaps(tables["bookings"], "port_id")
        _validate_booking_overlaps(tables["bookings"], "parking_space_id")
        _validate_booking_state_events(tables["booking_events"])

        booking_compatibility = (
            tables["bookings"][["vehicle_id", "port_id"]]
            .merge(tables["charger_ports"][["port_id", "connector_type_id"]], on="port_id")
            .merge(
                tables["vehicle_connectors"][["vehicle_id", "connector_type_id"]],
                on=["vehicle_id", "connector_type_id"],
                how="left",
                indicator=True,
            )
        )
        if bool((booking_compatibility["_merge"] != "both").any()):
            raise DatasetValidationError("a booking pairs a vehicle with an incompatible port")

    sessions = tables["charging_sessions"]
    completed = sessions[sessions["status"] == "completed"]
    if bool(completed["charging_started_at"].isna().any()) or bool(
        completed["charging_ended_at"].isna().any()
    ):
        raise DatasetValidationError("completed sessions require charging start and end")
    if bool((completed["charging_ended_at"] <= completed["charging_started_at"]).any()):
        raise DatasetValidationError("session end must be later than session start")
    if bool((sessions["energy_kwh"] < 0).any()):
        raise DatasetValidationError("session energy cannot be negative")
    for soc_column in ("start_soc", "end_soc"):
        values = pd.to_numeric(sessions[soc_column], errors="coerce").dropna()
        if bool(((values < 0) | (values > 100)).any()):
            raise DatasetValidationError(f"{soc_column} must remain between 0 and 100")

    observations = tables["availability_observations"]
    if bool((observations["feature_cutoff"] > observations["prediction_origin"]).any()):
        raise DatasetValidationError(
            "availability features use information after prediction origin"
        )
    label_values = set(observations["availability_label"].dropna().astype(bool))
    if not label_values.issubset({True, False}):
        raise DatasetValidationError("availability label must be true, false, or unknown")

    expected_buckets = (
        config.synthetic.zone_count
        * config.synthetic.days
        * (24 * 60 // config.time.bucket_minutes)
    )
    if len(tables["demand_buckets"]) != expected_buckets:
        raise DatasetValidationError(
            f"demand grid has {len(tables['demand_buckets'])} rows; expected {expected_buckets}"
        )
    if bool((tables["demand_buckets"]["request_count"] < 0).any()):
        raise DatasetValidationError("demand counts cannot be negative")

    run_ids: set[Any] = set()
    for frame in tables.values():
        if "simulation_run_id" in frame and not frame.empty:
            run_ids.update(frame["simulation_run_id"].dropna().unique().tolist())
    if len(run_ids) != 1:
        raise DatasetValidationError(
            f"all rows must share exactly one simulation_run_id: {run_ids}"
        )
