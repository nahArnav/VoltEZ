"""Fail-fast invariants for generated VoltEZ datasets."""

from __future__ import annotations

import json
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


def _require_unique(frame: pd.DataFrame, columns: list[str], table_name: str) -> None:
    if bool(frame.duplicated(columns, keep=False).any()):
        raise DatasetValidationError(f"{table_name} contains duplicate key {columns}")


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
        "users",
        "zones",
        "connector_types",
        "vehicle_connectors",
        "vehicles",
        "businesses",
        "business_hours",
        "business_hour_exceptions",
        "amenities",
        "business_amenities",
        "business_offers",
        "chargers",
        "charger_ports",
        "parking_spaces",
        "availability_windows",
        "tariffs",
        "charging_requests",
        "trips",
        "trip_charger_options",
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

    _require_foreign_keys(tables["businesses"], "owner_id", tables["users"], "user_id")
    _require_foreign_keys(tables["chargers"], "business_id", tables["businesses"], "business_id")
    _require_foreign_keys(tables["chargers"], "zone_id", tables["zones"], "zone_id")
    _require_foreign_keys(tables["charger_ports"], "charger_id", tables["chargers"], "charger_id")
    _require_foreign_keys(
        tables["charger_ports"], "connector_type_id", tables["connector_types"], "connector_type_id"
    )
    _require_foreign_keys(tables["parking_spaces"], "charger_id", tables["chargers"], "charger_id")
    _require_foreign_keys(
        tables["availability_windows"], "port_id", tables["charger_ports"], "port_id"
    )
    _require_foreign_keys(tables["tariffs"], "charger_id", tables["chargers"], "charger_id")
    _require_foreign_keys(tables["tariffs"], "port_id", tables["charger_ports"], "port_id")
    _require_foreign_keys(tables["vehicles"], "user_id", tables["users"], "user_id")
    _require_foreign_keys(
        tables["charging_requests"], "vehicle_id", tables["vehicles"], "vehicle_id"
    )
    _require_foreign_keys(tables["charging_requests"], "user_id", tables["users"], "user_id")
    _require_foreign_keys(tables["charging_requests"], "zone_id", tables["zones"], "zone_id")
    _require_foreign_keys(tables["trips"], "user_id", tables["users"], "user_id")
    _require_foreign_keys(tables["trips"], "vehicle_id", tables["vehicles"], "vehicle_id")
    _require_foreign_keys(tables["charging_requests"], "trip_id", tables["trips"], "trip_id")
    _require_foreign_keys(tables["trip_charger_options"], "trip_id", tables["trips"], "trip_id")
    _require_foreign_keys(
        tables["trip_charger_options"], "charger_id", tables["chargers"], "charger_id"
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
    _require_foreign_keys(
        tables["charging_sessions"], "booking_id", tables["bookings"], "booking_id"
    )
    _require_foreign_keys(
        tables["charging_sessions"], "port_id", tables["charger_ports"], "port_id"
    )
    _require_foreign_keys(
        tables["charger_status_events"], "port_id", tables["charger_ports"], "port_id"
    )

    for table_name, identifier in (
        ("users", "user_id"),
        ("zones", "zone_id"),
        ("businesses", "business_id"),
        ("chargers", "charger_id"),
        ("charger_ports", "port_id"),
        ("parking_spaces", "parking_space_id"),
        ("vehicles", "vehicle_id"),
        ("charging_requests", "request_id"),
        ("trips", "trip_id"),
        ("bookings", "booking_id"),
        ("charging_sessions", "session_id"),
        ("availability_observations", "observation_id"),
    ):
        _require_unique(tables[table_name], [identifier], table_name)
    _require_unique(tables["users"], ["email"], "users")
    _require_unique(tables["charger_ports"], ["charger_id", "port_number"], "charger_ports")
    _require_unique(
        tables["vehicle_connectors"],
        ["vehicle_id", "connector_type_id"],
        "vehicle_connectors",
    )

    if bool(
        (
            tables["availability_windows"]["end_at"] <= tables["availability_windows"]["start_at"]
        ).any()
    ):
        raise DatasetValidationError("availability window end_at must be later than start_at")
    if bool((tables["tariffs"]["ends_at"] <= tables["tariffs"]["starts_at"]).any()):
        raise DatasetValidationError("tariff ends_at must be later than starts_at")
    for price_column in ("price_per_kwh", "price_per_minute", "booking_fee"):
        if bool((tables["tariffs"][price_column] < 0).any()):
            raise DatasetValidationError(f"tariff {price_column} cannot be negative")

    request_ownership = tables["charging_requests"][["user_id", "vehicle_id"]].merge(
        tables["vehicles"][["vehicle_id", "user_id"]],
        on="vehicle_id",
        suffixes=("_request", "_vehicle"),
    )
    if bool((request_ownership["user_id_request"] != request_ownership["user_id_vehicle"]).any()):
        raise DatasetValidationError("request user does not own the referenced vehicle")
    route_requests = tables["charging_requests"][
        tables["charging_requests"]["request_type"] == "route_planning"
    ]
    if bool(route_requests["trip_id"].isna().any()):
        raise DatasetValidationError("every route-planning request requires a trip")
    non_route_requests = tables["charging_requests"][
        tables["charging_requests"]["request_type"] != "route_planning"
    ]
    if bool(non_route_requests["trip_id"].notna().any()):
        raise DatasetValidationError("only route-planning requests may reference a trip")
    if bool((tables["trip_charger_options"]["estimated_detour_km"] < 0).any()):
        raise DatasetValidationError("trip detour cannot be negative")
    if bool((tables["trip_charger_options"]["estimated_total_cost"] < 0).any()):
        raise DatasetValidationError("trip estimated cost cannot be negative")
    _require_unique(
        tables["trip_charger_options"],
        ["trip_id", "charger_id"],
        "trip_charger_options",
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

        booking_ownership = tables["bookings"][["user_id", "vehicle_id"]].merge(
            tables["vehicles"][["vehicle_id", "user_id"]],
            on="vehicle_id",
            suffixes=("_booking", "_vehicle"),
        )
        if bool(
            (booking_ownership["user_id_booking"] != booking_ownership["user_id_vehicle"]).any()
        ):
            raise DatasetValidationError("booking user does not own the referenced vehicle")
        for quote in tables["bookings"]["quote_snapshot"]:
            parsed_quote = json.loads(str(quote))
            if parsed_quote.get("currency") != "INR":
                raise DatasetValidationError("booking quote currency must be INR in Pune v1")
            for field in ("price_per_kwh", "price_per_minute", "booking_fee"):
                if float(parsed_quote[field]) < 0:
                    raise DatasetValidationError(f"booking quote {field} cannot be negative")

        parking_alignment = (
            tables["bookings"][["booking_id", "port_id", "parking_space_id"]]
            .merge(
                tables["charger_ports"][["port_id", "charger_id"]],
                on="port_id",
            )
            .merge(
                tables["parking_spaces"][["parking_space_id", "charger_id"]],
                on="parking_space_id",
                suffixes=("_port", "_parking"),
            )
        )
        if bool(
            (parking_alignment["charger_id_port"] != parking_alignment["charger_id_parking"]).any()
        ):
            raise DatasetValidationError("a booking reserves parking from another charger")

    sessions = tables["charging_sessions"]
    completed = sessions[sessions["status"] == "completed"]
    if bool(completed["start_at"].isna().any()) or bool(completed["end_at"].isna().any()):
        raise DatasetValidationError("completed sessions require charging start and end")
    if bool((completed["end_at"] <= completed["start_at"]).any()):
        raise DatasetValidationError("session end must be later than session start")
    if bool((sessions["energy_kwh"] < 0).any()):
        raise DatasetValidationError("session energy cannot be negative")
    if bool((sessions["final_amount"] < 0).any()):
        raise DatasetValidationError("session final amount cannot be negative")
    meter_delta = completed["meter_end_kwh"] - completed["meter_start_kwh"]
    if bool(((meter_delta - completed["energy_kwh"]).abs() > 0.002).any()):
        raise DatasetValidationError("session energy does not match auditable meter delta")
    for soc_column in ("start_soc", "end_soc"):
        values = pd.to_numeric(sessions[soc_column], errors="coerce").dropna()
        if bool(((values < 0) | (values > 100)).any()):
            raise DatasetValidationError(f"{soc_column} must remain between 0 and 100")

    observations = tables["availability_observations"]
    if bool((observations["feature_cutoff"] > observations["prediction_origin"]).any()):
        raise DatasetValidationError(
            "availability features use information after prediction origin"
        )
    if bool((observations["target_arrival_at"] < observations["prediction_origin"]).any()):
        raise DatasetValidationError("availability target cannot precede prediction origin")
    label_values = set(observations["label"].astype(str))
    if not label_values.issubset({"available", "unavailable", "unknown"}):
        raise DatasetValidationError(
            "availability label must be available, unavailable, or unknown"
        )
    known_observations = observations[observations["label"] != "unknown"]
    if not known_observations.empty:
        latent_check = known_observations[["observation_id", "label"]].merge(
            tables["qa_latent_availability"][["observation_id", "latent_available"]],
            on="observation_id",
            validate="one_to_one",
        )
        expected_labels = latent_check["latent_available"].map(
            {True: "available", False: "unavailable"}
        )
        if bool((latent_check["label"] != expected_labels).any()):
            raise DatasetValidationError("observed availability labels contradict latent QA truth")

    status_events = tables["charger_status_events"]
    if bool((status_events["ingested_at"] < status_events["observed_at"]).any()):
        raise DatasetValidationError("status event cannot be ingested before it was observed")
    if bool(((status_events["confidence"] < 0) | (status_events["confidence"] > 1)).any()):
        raise DatasetValidationError("status confidence must remain between zero and one")
    status_alignment = status_events[["charger_id", "port_id"]].merge(
        tables["charger_ports"][["port_id", "charger_id"]],
        on="port_id",
        suffixes=("_event", "_port"),
    )
    if bool((status_alignment["charger_id_event"] != status_alignment["charger_id_port"]).any()):
        raise DatasetValidationError("status event charger and port disagree")

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
    demand = tables["demand_buckets"]
    if bool((demand["search_count"] > demand["request_count"]).any()):
        raise DatasetValidationError("search_count is a subset and cannot exceed request_count")
    if bool((demand["unserved_count"] > demand["request_count"]).any()):
        raise DatasetValidationError("unserved_count cannot exceed request_count")
    if bool(((demand["occupancy_rate"] < 0) | (demand["occupancy_rate"] > 1)).any()):
        raise DatasetValidationError("occupancy_rate must remain between zero and one")
    if int(demand["request_count"].sum()) != len(tables["charging_requests"]):
        raise DatasetValidationError("demand bucket requests do not reconcile to raw requests")

    run_ids: set[Any] = set()
    for frame in tables.values():
        if "simulation_run_id" in frame and not frame.empty:
            run_ids.update(frame["simulation_run_id"].dropna().unique().tolist())
    if len(run_ids) != 1:
        raise DatasetValidationError(
            f"all rows must share exactly one simulation_run_id: {run_ids}"
        )
