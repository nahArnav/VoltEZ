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
        + settings.driver_count * 4
        + 5
    )
    per_request_rows = 9 + settings.behaviour.recommendations_per_request * 4
    event_rows = grid_rows * 2 + expected_requests_with_headroom * per_request_rows
    route_coverage_rows = (
        settings.driver_count * settings.route_energy.coverage_trips_per_vehicle * 2
    )
    status_headroom = maximum_ports * (1 + settings.days * 2)
    return static_rows + event_rows + route_coverage_rows + status_headroom


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
        ("charging", "failed"),
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
        "vehicle_energy_profiles",
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
        "route_snapshots",
        "trip_charger_options",
        "recommendation_impressions",
        "bookings",
        "booking_events",
        "charging_sessions",
        "charger_status_events",
        "demand_buckets",
        "availability_observations",
        "waiting_time_observations",
        "reliability_observations",
        "qa_latent_demand",
        "qa_latent_outages",
        "qa_latent_availability",
        "qa_latent_port_profiles",
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
        tables["qa_latent_port_profiles"], "port_id", tables["charger_ports"], "port_id"
    )
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
        tables["vehicle_energy_profiles"], "vehicle_id", tables["vehicles"], "vehicle_id"
    )
    _require_foreign_keys(
        tables["charging_requests"], "vehicle_id", tables["vehicles"], "vehicle_id"
    )
    _require_foreign_keys(tables["charging_requests"], "user_id", tables["users"], "user_id")
    _require_foreign_keys(tables["charging_requests"], "zone_id", tables["zones"], "zone_id")
    _require_foreign_keys(tables["trips"], "user_id", tables["users"], "user_id")
    _require_foreign_keys(tables["trips"], "vehicle_id", tables["vehicles"], "vehicle_id")
    _require_foreign_keys(tables["route_snapshots"], "trip_id", tables["trips"], "trip_id")
    _require_foreign_keys(
        tables["route_snapshots"], "request_id", tables["charging_requests"], "request_id"
    )
    _require_foreign_keys(
        tables["route_snapshots"], "vehicle_id", tables["vehicles"], "vehicle_id"
    )
    candidate_snapshots = tables["route_snapshots"][
        tables["route_snapshots"]["candidate_charger_id"].notna()
    ]
    _require_foreign_keys(
        candidate_snapshots, "candidate_charger_id", tables["chargers"], "charger_id"
    )
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
    for observation_table in ("waiting_time_observations", "reliability_observations"):
        _require_foreign_keys(
            tables[observation_table], "request_id", tables["charging_requests"], "request_id"
        )
        _require_foreign_keys(
            tables[observation_table], "port_id", tables["charger_ports"], "port_id"
        )
        _require_foreign_keys(
            tables[observation_table], "session_id", tables["charging_sessions"], "session_id"
        )

    for table_name, identifier in (
        ("users", "user_id"),
        ("zones", "zone_id"),
        ("businesses", "business_id"),
        ("chargers", "charger_id"),
        ("charger_ports", "port_id"),
        ("parking_spaces", "parking_space_id"),
        ("vehicles", "vehicle_id"),
        ("vehicle_energy_profiles", "vehicle_energy_profile_id"),
        ("charging_requests", "request_id"),
        ("trips", "trip_id"),
        ("route_snapshots", "route_snapshot_id"),
        ("bookings", "booking_id"),
        ("charging_sessions", "session_id"),
        ("availability_observations", "observation_id"),
        ("waiting_time_observations", "waiting_observation_id"),
        ("reliability_observations", "reliability_observation_id"),
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
    trip_ownership = tables["trips"][["user_id", "vehicle_id"]].merge(
        tables["vehicles"][["vehicle_id", "user_id"]],
        on="vehicle_id",
        suffixes=("_trip", "_vehicle"),
    )
    if bool((trip_ownership["user_id_trip"] != trip_ownership["user_id_vehicle"]).any()):
        raise DatasetValidationError("trip user does not own the referenced vehicle")
    if bool((tables["trip_charger_options"]["estimated_detour_km"] < 0).any()):
        raise DatasetValidationError("trip detour cannot be negative")
    if bool((tables["trip_charger_options"]["estimated_total_cost"] < 0).any()):
        raise DatasetValidationError("trip estimated cost cannot be negative")
    _require_unique(
        tables["trip_charger_options"],
        ["trip_id", "charger_id"],
        "trip_charger_options",
    )

    profiles = tables["vehicle_energy_profiles"]
    route_snapshots = tables["route_snapshots"]
    if config.synthetic.route_energy.enabled:
        if len(profiles) != len(tables["vehicles"]):
            raise DatasetValidationError("every vehicle requires one active energy profile")
        _require_unique(profiles, ["vehicle_id"], "vehicle_energy_profiles")
        if bool(profiles["effective_from"].isna().any()):
            raise DatasetValidationError("vehicle energy profiles require effective_from")
        ended_profiles = profiles[profiles["effective_to"].notna()]
        if not ended_profiles.empty:
            effective_to = pd.to_datetime(ended_profiles["effective_to"], utc=True)
            effective_from = pd.to_datetime(ended_profiles["effective_from"], utc=True)
            if bool((effective_to <= effective_from).any()):
                raise DatasetValidationError(
                    "vehicle energy profile validity interval is invalid"
                )
        expected_profile_sources = {"catalogue", "owner_declared", "class_default"}
        if not set(profiles["source"].astype(str)).issubset(expected_profile_sources):
            raise DatasetValidationError("vehicle energy profile source is invalid")
        bounded_profile_columns = {
            "confidence": (0.0, 1.0),
            "curb_mass_kg": (80.0, 3_100.0),
            "default_payload_kg": (0.0, 900.0),
            "drag_area_m2": (0.3, 2.0),
            "rolling_resistance_coefficient": (0.005, 0.04),
            "drivetrain_efficiency": (0.5, 1.0),
            "regenerative_braking_efficiency": (0.0, 0.95),
            "usable_capacity_fraction": (0.5, 1.0),
            "battery_health_fraction": (0.5, 1.0),
        }
        for column, (minimum, maximum) in bounded_profile_columns.items():
            if bool(((profiles[column] < minimum) | (profiles[column] > maximum)).any()):
                raise DatasetValidationError(
                    f"vehicle energy profile {column} is outside its physical bounds"
                )

        expected_snapshot_count = len(tables["trips"]) + len(tables["trip_charger_options"])
        if len(route_snapshots) != expected_snapshot_count:
            raise DatasetValidationError(
                "route snapshots must cover every direct trip and candidate charger option"
            )
        snapshot_vehicle_alignment = route_snapshots[["trip_id", "vehicle_id"]].merge(
            tables["trips"][["trip_id", "vehicle_id"]],
            on="trip_id",
            suffixes=("_snapshot", "_trip"),
            validate="many_to_one",
        )
        if bool(
            (
                snapshot_vehicle_alignment["vehicle_id_snapshot"]
                != snapshot_vehicle_alignment["vehicle_id_trip"]
            ).any()
        ):
            raise DatasetValidationError("route snapshot vehicle does not match its trip")
        request_snapshots = route_snapshots[route_snapshots["request_id"].notna()]
        request_alignment = request_snapshots[["trip_id", "request_id"]].merge(
            tables["charging_requests"][["request_id", "trip_id"]],
            on="request_id",
            suffixes=("_snapshot", "_request"),
            validate="many_to_one",
        )
        if bool(
            (
                request_alignment["trip_id_snapshot"]
                != request_alignment["trip_id_request"]
            ).any()
        ):
            raise DatasetValidationError("route snapshot request does not match its trip")
        if bool(tables["trips"]["direct_route_snapshot_id"].isna().any()):
            raise DatasetValidationError("every trip requires a direct route snapshot")
        if bool(tables["trip_charger_options"]["route_snapshot_id"].isna().any()):
            raise DatasetValidationError("every charger option requires a route snapshot")
        _require_foreign_keys(
            tables["trips"],
            "direct_route_snapshot_id",
            route_snapshots,
            "route_snapshot_id",
        )
        _require_foreign_keys(
            tables["trip_charger_options"],
            "route_snapshot_id",
            route_snapshots,
            "route_snapshot_id",
        )

        direct_snapshots = route_snapshots[route_snapshots["leg_type"] == "destination"]
        candidate_snapshots = route_snapshots[
            route_snapshots["leg_type"] == "candidate_charger"
        ]
        if len(direct_snapshots) != len(tables["trips"]):
            raise DatasetValidationError("each trip must have exactly one destination snapshot")
        if len(candidate_snapshots) != len(tables["trip_charger_options"]):
            raise DatasetValidationError("each charger option must have one candidate snapshot")
        if bool(direct_snapshots["candidate_charger_id"].notna().any()):
            raise DatasetValidationError("destination snapshots cannot reference a charger")
        if bool(candidate_snapshots["candidate_charger_id"].isna().any()):
            raise DatasetValidationError("candidate snapshots require a charger")
        candidate_alignment = tables["trip_charger_options"][
            ["route_snapshot_id", "charger_id"]
        ].merge(
            candidate_snapshots[["route_snapshot_id", "candidate_charger_id"]],
            on="route_snapshot_id",
            validate="one_to_one",
        )
        if bool(
            (
                candidate_alignment["charger_id"]
                != candidate_alignment["candidate_charger_id"]
            ).any()
        ):
            raise DatasetValidationError(
                "charger option and route snapshot reference different chargers"
            )

        if bool(
            (route_snapshots["requested_at"] > route_snapshots["route_snapshot_at"]).any()
        ):
            raise DatasetValidationError("route snapshot cannot predate its request")
        if bool((route_snapshots["route_snapshot_at"] >= route_snapshots["expires_at"]).any()):
            raise DatasetValidationError("route snapshot expiry must follow generation")
        if bool((route_snapshots["distance_km"] <= 0).any()):
            raise DatasetValidationError("route snapshot distance must be positive")
        if bool((route_snapshots["normal_duration_minutes"] <= 0).any()):
            raise DatasetValidationError("route normal duration must be positive")
        if bool(
            (
                route_snapshots["traffic_duration_minutes"]
                < route_snapshots["normal_duration_minutes"]
            ).any()
        ):
            raise DatasetValidationError("traffic duration cannot be shorter than normal duration")
        reconciled_traffic_duration = (
            route_snapshots["normal_duration_minutes"]
            * route_snapshots["traffic_delay_ratio"]
        )
        ratio_rounding_tolerance = (
            0.00051 * (route_snapshots["traffic_delay_ratio"] + 1.0)
            + route_snapshots["normal_duration_minutes"] * 0.0000051
        )
        if bool(
            (reconciled_traffic_duration - route_snapshots["traffic_duration_minutes"])
            .abs()
            .gt(ratio_rounding_tolerance)
            .any()
        ):
            raise DatasetValidationError("route traffic delay ratio does not match durations")
        if bool(
            (
                route_snapshots["urban_fraction"]
                + route_snapshots["highway_fraction"]
                - 1.0
            )
            .abs()
            .gt(0.00001)
            .any()
        ):
            raise DatasetValidationError("urban and highway route fractions must sum to one")
        if bool((route_snapshots["estimated_full_stop_count"] < 0).any()):
            raise DatasetValidationError("route stop count cannot be negative")

        elevation_columns = [
            "elevation_gain_m",
            "elevation_loss_m",
            "mean_grade_percent",
            "maximum_grade_percent",
        ]
        elevation_missing = route_snapshots["elevation_source_quality"] == "missing"
        if bool(route_snapshots.loc[elevation_missing, elevation_columns].notna().any().any()):
            raise DatasetValidationError("missing elevation context must not contain values")
        if bool(route_snapshots.loc[~elevation_missing, elevation_columns].isna().any().any()):
            raise DatasetValidationError("known elevation context requires all summary values")
        weather_columns = [
            "ambient_temperature_c",
            "precipitation_mm_h",
            "headwind_mps",
            "air_density_kg_m3",
            "weather_observed_at",
            "weather_ingested_at",
        ]
        weather_missing = route_snapshots["weather_source_quality"] == "missing"
        if bool(route_snapshots.loc[weather_missing, weather_columns].notna().any().any()):
            raise DatasetValidationError("missing weather context must not contain values")
        if bool(route_snapshots.loc[~weather_missing, weather_columns].isna().any().any()):
            raise DatasetValidationError("known weather context requires all values")
        if bool(
            (
                route_snapshots.loc[~weather_missing, "weather_ingested_at"]
                < route_snapshots.loc[~weather_missing, "weather_observed_at"]
            ).any()
        ):
            raise DatasetValidationError("weather cannot be ingested before observation")

        forbidden_route_fields = {
            "actual_battery_energy_kwh",
            "actual_arrival_soc_percent",
            "qa_driver_aggressiveness",
            "qa_true_vehicle_coefficients",
            "qa_segment_speed_trace",
        }
        leaked_route_fields = forbidden_route_fields.intersection(route_snapshots.columns)
        if leaked_route_fields:
            raise DatasetValidationError(
                f"Step 3 truth leaked into Step 2 route snapshots: {sorted(leaked_route_fields)}"
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
    started = sessions[sessions["start_at"].notna()]
    if bool(started["service_ready_at"].isna().any()):
        raise DatasetValidationError("started sessions require a known service_ready_at")
    if bool((started["start_at"] < started["service_ready_at"]).any()):
        raise DatasetValidationError("charging cannot start before the port is service-ready")
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

    waiting = tables["waiting_time_observations"]
    known_waiting = waiting[waiting["label_known"] == 1]
    if bool(known_waiting["label_wait_minutes"].isna().any()):
        raise DatasetValidationError("known waiting labels cannot be null")
    if bool((known_waiting["label_wait_minutes"] < 0).any()):
        raise DatasetValidationError("waiting-time labels cannot be negative")
    if bool((waiting["feature_cutoff"] > waiting["prediction_origin"]).any()):
        raise DatasetValidationError("waiting-time features use future information")

    reliability = tables["reliability_observations"]
    if not set(reliability["label"].astype(str)).issubset(
        {"reliable", "unreliable", "unknown"}
    ):
        raise DatasetValidationError("reliability label has an invalid state")
    if bool((reliability["feature_cutoff"] > reliability["prediction_origin"]).any()):
        raise DatasetValidationError("reliability features use future information")

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
