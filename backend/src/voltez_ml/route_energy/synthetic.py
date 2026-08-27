"""Generate public, planning-time inputs for the Model 5 synthetic dataset.

This module deliberately creates no realized-energy label and no hidden truth. Step 2 only adds
schema-compatible vehicle energy profiles and immutable route snapshots. Segment-level truth,
driver behavior, and true physical coefficients belong to the separately approved Step 3.
"""

from __future__ import annotations

import math
from datetime import date, timedelta
from typing import Any, cast

import numpy as np
import pandas as pd
from numpy.random import Generator

from voltez_ml.config import VoltEZConfig
from voltez_ml.geography import haversine_km
from voltez_ml.synthetic.randomness import named_rng, stable_hash, stable_id

PROFILE_COLUMNS = [
    "vehicle_energy_profile_id",
    "vehicle_id",
    "effective_from",
    "effective_to",
    "source",
    "confidence",
    "curb_mass_kg",
    "default_payload_kg",
    "drag_area_m2",
    "rolling_resistance_coefficient",
    "drivetrain_efficiency",
    "regenerative_braking_efficiency",
    "usable_capacity_fraction",
    "battery_health_fraction",
    "profile_version",
    "simulation_run_id",
]

ROUTE_SNAPSHOT_COLUMNS = [
    "route_snapshot_id",
    "trip_id",
    "request_id",
    "vehicle_id",
    "candidate_charger_id",
    "leg_type",
    "provider",
    "provider_route_id",
    "route_hash",
    "requested_at",
    "route_snapshot_at",
    "expires_at",
    "origin_latitude",
    "origin_longitude",
    "destination_latitude",
    "destination_longitude",
    "distance_km",
    "normal_duration_minutes",
    "traffic_duration_minutes",
    "traffic_delay_ratio",
    "elevation_gain_m",
    "elevation_loss_m",
    "mean_grade_percent",
    "maximum_grade_percent",
    "urban_fraction",
    "highway_fraction",
    "estimated_full_stop_count",
    "ambient_temperature_c",
    "precipitation_mm_h",
    "headwind_mps",
    "air_density_kg_m3",
    "road_surface_state",
    "route_source_quality",
    "elevation_source_quality",
    "weather_source_quality",
    "weather_observed_at",
    "weather_ingested_at",
    "simulation_run_id",
]

TRIP_COLUMNS = [
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

_PROFILE_SOURCE_CONFIDENCE = {
    "catalogue": 0.92,
    "owner_declared": 0.68,
    "class_default": 0.42,
}

# Public priors, not hidden ground truth. Each tuple is (low, typical, high).
_VEHICLE_CLASS_PRIORS: dict[str, dict[str, tuple[float, float, float]]] = {
    "two_wheeler": {
        "curb_mass_kg": (85.0, 115.0, 170.0),
        "default_payload_kg": (55.0, 78.0, 145.0),
        "drag_area_m2": (0.42, 0.55, 0.78),
        "rolling_resistance_coefficient": (0.012, 0.018, 0.028),
        "drivetrain_efficiency": (0.82, 0.88, 0.93),
        "regenerative_braking_efficiency": (0.05, 0.20, 0.38),
        "usable_capacity_fraction": (0.84, 0.91, 0.96),
    },
    "three_wheeler": {
        "curb_mass_kg": (280.0, 390.0, 560.0),
        "default_payload_kg": (80.0, 170.0, 360.0),
        "drag_area_m2": (1.05, 1.35, 1.85),
        "rolling_resistance_coefficient": (0.013, 0.019, 0.028),
        "drivetrain_efficiency": (0.80, 0.86, 0.92),
        "regenerative_braking_efficiency": (0.08, 0.24, 0.45),
        "usable_capacity_fraction": (0.83, 0.90, 0.96),
    },
    "car": {
        "curb_mass_kg": (950.0, 1_550.0, 2_350.0),
        "default_payload_kg": (55.0, 125.0, 320.0),
        "drag_area_m2": (0.50, 0.66, 0.95),
        "rolling_resistance_coefficient": (0.008, 0.011, 0.017),
        "drivetrain_efficiency": (0.84, 0.90, 0.95),
        "regenerative_braking_efficiency": (0.35, 0.62, 0.80),
        "usable_capacity_fraction": (0.86, 0.94, 0.98),
    },
    "van": {
        "curb_mass_kg": (1_450.0, 2_050.0, 2_950.0),
        "default_payload_kg": (120.0, 360.0, 850.0),
        "drag_area_m2": (0.78, 1.02, 1.48),
        "rolling_resistance_coefficient": (0.009, 0.013, 0.019),
        "drivetrain_efficiency": (0.82, 0.88, 0.94),
        "regenerative_braking_efficiency": (0.28, 0.52, 0.72),
        "usable_capacity_fraction": (0.84, 0.92, 0.97),
    },
}


def _records(frame: pd.DataFrame) -> list[dict[str, Any]]:
    return cast(list[dict[str, Any]], frame.to_dict("records"))


def _bounded_triangular(
    rng: Generator,
    bounds: tuple[float, float, float],
    source: str,
) -> float:
    low, typical, high = bounds
    if source == "class_default":
        return typical
    value = float(rng.triangular(low, typical, high))
    if source == "owner_declared":
        # Owner-entered specifications are coarser than catalogue values but remain plausible.
        value *= float(rng.normal(1.0, 0.035))
    return float(np.clip(value, low, high))


def generate_vehicle_energy_profiles(
    config: VoltEZConfig,
    run_id: str,
    vehicles: pd.DataFrame,
) -> pd.DataFrame:
    """Create one versioned, public physical-prior record per synthetic vehicle."""

    if not config.synthetic.route_energy.enabled:
        return pd.DataFrame(columns=PROFILE_COLUMNS)

    rng = named_rng(config.project.seed, "route-energy-public-vehicle-profiles-v1")
    source_names = ("catalogue", "owner_declared", "class_default")
    source_probabilities = [
        config.synthetic.route_energy.profile_source_mix[name] for name in source_names
    ]
    effective_from = pd.Timestamp(config.synthetic.start_date, tz=config.project.timezone)
    rows: list[dict[str, Any]] = []
    for vehicle in _records(vehicles):
        vehicle_class = str(vehicle["vehicle_class"])
        priors = _VEHICLE_CLASS_PRIORS[vehicle_class]
        source = str(rng.choice(source_names, p=source_probabilities))
        values = {
            field: _bounded_triangular(rng, bounds, source)
            for field, bounds in priors.items()
        }
        # Health is an estimated, planning-time value. It is intentionally not the hidden true
        # health that Step 3 will use when producing an energy label.
        battery_health = float(np.clip(0.82 + 0.18 * rng.beta(5.5, 1.7), 0.82, 1.0))
        if source == "class_default":
            battery_health = 0.92
        rows.append(
            {
                "vehicle_energy_profile_id": stable_id(
                    run_id, "vehicle-energy-profile", str(vehicle["vehicle_id"])
                ),
                "vehicle_id": vehicle["vehicle_id"],
                "effective_from": effective_from,
                "effective_to": pd.NaT,
                "source": source,
                "confidence": _PROFILE_SOURCE_CONFIDENCE[source],
                "curb_mass_kg": round(values["curb_mass_kg"], 2),
                "default_payload_kg": round(values["default_payload_kg"], 2),
                "drag_area_m2": round(values["drag_area_m2"], 4),
                "rolling_resistance_coefficient": round(
                    values["rolling_resistance_coefficient"], 6
                ),
                "drivetrain_efficiency": round(values["drivetrain_efficiency"], 5),
                "regenerative_braking_efficiency": round(
                    values["regenerative_braking_efficiency"], 5
                ),
                "usable_capacity_fraction": round(values["usable_capacity_fraction"], 5),
                "battery_health_fraction": round(battery_health, 5),
                "profile_version": "synthetic-public-v1",
                "simulation_run_id": run_id,
            }
        )
    return pd.DataFrame(rows, columns=PROFILE_COLUMNS)


def _traffic_peak(hour: float) -> float:
    morning = math.exp(-0.5 * ((hour - 8.7) / 1.6) ** 2)
    evening = 1.15 * math.exp(-0.5 * ((hour - 18.8) / 1.8) ** 2)
    return min(1.0, morning + evening)


def _destination_point(
    latitude: float,
    longitude: float,
    bearing_radians: float,
    distance_km: float,
) -> tuple[float, float]:
    """Move along a great-circle bearing so route length agrees with its coordinates."""

    earth_radius_km = 6_371.0088
    angular_distance = distance_km / earth_radius_km
    latitude_radians = math.radians(latitude)
    longitude_radians = math.radians(longitude)
    destination_latitude = math.asin(
        math.sin(latitude_radians) * math.cos(angular_distance)
        + math.cos(latitude_radians)
        * math.sin(angular_distance)
        * math.cos(bearing_radians)
    )
    destination_longitude = longitude_radians + math.atan2(
        math.sin(bearing_radians)
        * math.sin(angular_distance)
        * math.cos(latitude_radians),
        math.cos(angular_distance)
        - math.sin(latitude_radians) * math.sin(destination_latitude),
    )
    return math.degrees(destination_latitude), math.degrees(destination_longitude)


def _generate_coverage_trips(
    config: VoltEZConfig,
    run_id: str,
    vehicles: pd.DataFrame,
    zones: pd.DataFrame,
) -> tuple[pd.DataFrame, dict[str, tuple[pd.Timestamp, str]]]:
    """Add ordinary driver journeys that cover route lengths absent from charger searches."""

    rng = named_rng(config.project.seed, "route-energy-public-coverage-trips-v1")
    trip_count = config.synthetic.route_energy.coverage_trips_per_vehicle
    if not config.synthetic.route_energy.enabled or trip_count == 0:
        return pd.DataFrame(columns=TRIP_COLUMNS), {}

    zone_records = _records(zones)
    distance_bands = {
        "urban_short": (2.0, 12.0),
        "urban_medium": (12.0, 30.0),
        "regional_highway": (30.0, 90.0),
        "intercity": (90.0, 220.0),
    }
    band_names = tuple(distance_bands)
    band_probabilities = (0.28, 0.28, 0.29, 0.15)
    dataset_start = pd.Timestamp(config.synthetic.start_date, tz=config.project.timezone)
    rows: list[dict[str, Any]] = []
    context: dict[str, tuple[pd.Timestamp, str]] = {}
    for vehicle in _records(vehicles):
        for sequence in range(trip_count):
            origin = zone_records[int(rng.integers(0, len(zone_records)))]
            band = str(rng.choice(band_names, p=band_probabilities))
            minimum_distance, maximum_distance = distance_bands[band]
            planned_road_distance = float(rng.uniform(minimum_distance, maximum_distance))
            assumed_road_factor = float(rng.uniform(1.16, 1.34))
            bearing = float(rng.uniform(0, 2 * math.pi))
            destination_latitude, destination_longitude = _destination_point(
                float(origin["centroid_latitude"]),
                float(origin["centroid_longitude"]),
                bearing,
                planned_road_distance / assumed_road_factor,
            )
            trip_id = stable_id(
                run_id,
                "route-energy-coverage-trip",
                f"{vehicle['vehicle_id']}:{sequence}",
            )
            requested_at = dataset_start + timedelta(
                days=int(rng.integers(0, config.synthetic.days)),
                minutes=int(rng.integers(5 * 60, 23 * 60)),
            )
            rows.append(
                {
                    "trip_id": trip_id,
                    "user_id": vehicle["user_id"],
                    "vehicle_id": vehicle["vehicle_id"],
                    "start_latitude": round(float(origin["centroid_latitude"]), 7),
                    "start_longitude": round(float(origin["centroid_longitude"]), 7),
                    "destination_latitude": round(destination_latitude, 7),
                    "destination_longitude": round(destination_longitude, 7),
                    "started_at": pd.NaT,
                    "ended_at": pd.NaT,
                    "distance_km": round(planned_road_distance, 3),
                    "status": "planned",
                    "simulation_run_id": run_id,
                }
            )
            context[trip_id] = (requested_at, str(origin["zone_id"]))
    return pd.DataFrame(rows, columns=TRIP_COLUMNS), context


def _public_weather(
    rng: Generator,
    moment: pd.Timestamp,
    scenario: str,
    missing: bool,
) -> dict[str, Any]:
    if missing:
        return {
            "ambient_temperature_c": np.nan,
            "precipitation_mm_h": np.nan,
            "headwind_mps": np.nan,
            "air_density_kg_m3": np.nan,
            "road_surface_state": "unknown",
            "weather_source_quality": "missing",
            "weather_observed_at": pd.NaT,
            "weather_ingested_at": pd.NaT,
        }

    diurnal = 4.8 * math.sin((moment.hour - 8) / 24 * 2 * math.pi)
    seasonal = 2.0 * math.sin((moment.dayofyear - 25) / 365 * 2 * math.pi)
    temperature = 24.0 + diurnal + seasonal + float(rng.normal(0, 1.4))
    if scenario == "monsoon_disruption":
        temperature = float(np.clip(24.0 + rng.normal(0, 1.6), 19.0, 29.0))
        precipitation = float(np.clip(rng.gamma(2.0, 2.2), 0.3, 18.0))
        wind_sigma = 4.0
    else:
        precipitation = (
            float(np.clip(rng.gamma(1.4, 1.1), 0.1, 8.0))
            if rng.random() < 0.035
            else 0.0
        )
        wind_sigma = 2.4
    headwind = float(np.clip(rng.normal(0.3, wind_sigma), -9.0, 12.0))
    temperature = float(np.clip(temperature, 12.0, 39.0))
    # Pune is around 560 m above sea level, so density is lower than the sea-level default.
    air_density = 1.16 * 293.15 / (temperature + 273.15)
    observed_at = moment - timedelta(minutes=int(rng.integers(5, 46)))
    ingested_at = observed_at + timedelta(minutes=int(rng.integers(1, 5)))
    return {
        "ambient_temperature_c": round(temperature, 2),
        "precipitation_mm_h": round(precipitation, 3),
        "headwind_mps": round(headwind, 3),
        "air_density_kg_m3": round(float(air_density), 5),
        "road_surface_state": "wet" if precipitation >= 0.2 else "dry",
        "weather_source_quality": "high" if rng.random() < 0.78 else "medium",
        "weather_observed_at": observed_at,
        "weather_ingested_at": ingested_at,
    }


def _route_morphology(
    rng: Generator,
    distance_km: float,
    scenario: str,
    steep_route: bool,
    elevation_missing: bool,
) -> dict[str, Any]:
    urban_fraction = float(
        np.clip(0.93 - 0.0145 * max(0.0, distance_km - 3.0) + rng.normal(0, 0.08), 0.12, 0.98)
    )
    highway_fraction = 1.0 - urban_fraction
    urban_speed_kph = float(np.clip(rng.normal(27.0, 3.2), 16.0, 36.0))
    highway_speed_kph = float(np.clip(rng.normal(67.0, 7.5), 45.0, 88.0))
    normal_duration = 60 * distance_km * (
        urban_fraction / urban_speed_kph + highway_fraction / highway_speed_kph
    )
    scenario_multiplier = {
        "normal_weekday": 1.0,
        "weekend_retail": 1.04,
        "monsoon_disruption": 1.34,
        "local_event_spike": 1.27,
        "outage_cluster": 1.04,
        "stale_status_reports": 1.0,
    }[scenario]
    # The time-of-day peak is supplied by the caller after route time is known.
    elevation_values: dict[str, Any]
    if elevation_missing:
        elevation_values = {
            "elevation_gain_m": np.nan,
            "elevation_loss_m": np.nan,
            "mean_grade_percent": np.nan,
            "maximum_grade_percent": np.nan,
            "elevation_source_quality": "missing",
        }
    else:
        vertical_metres_per_km = float(rng.gamma(2.2, 2.8))
        if steep_route:
            vertical_metres_per_km += float(rng.uniform(16.0, 34.0))
        total_vertical_change = max(1.0, distance_km * vertical_metres_per_km)
        net_change = float(
            np.clip(
                rng.normal(0, total_vertical_change * 0.34),
                -0.82 * total_vertical_change,
                0.82 * total_vertical_change,
            )
        )
        elevation_gain = (total_vertical_change + net_change) / 2
        elevation_loss = (total_vertical_change - net_change) / 2
        mean_grade = net_change / (distance_km * 1_000) * 100
        maximum_grade = float(
            np.clip(
                max(abs(mean_grade) + 0.4, rng.normal(7.2 if steep_route else 3.0, 1.2)),
                0.5,
                16.0,
            )
        )
        elevation_values = {
            "elevation_gain_m": round(elevation_gain, 2),
            "elevation_loss_m": round(elevation_loss, 2),
            "mean_grade_percent": round(mean_grade, 4),
            "maximum_grade_percent": round(maximum_grade, 3),
            "elevation_source_quality": "high" if rng.random() < 0.72 else "medium",
        }
    return {
        "urban_fraction": round(urban_fraction, 6),
        "highway_fraction": round(highway_fraction, 6),
        "normal_duration_minutes": normal_duration,
        "scenario_traffic_multiplier": scenario_multiplier,
        **elevation_values,
    }


def _build_route_snapshot(
    *,
    config: VoltEZConfig,
    rng: Generator,
    run_id: str,
    trip: dict[str, Any],
    request_id: str | None,
    requested_at: pd.Timestamp,
    destination_latitude: float,
    destination_longitude: float,
    destination_zone_id: str,
    candidate_charger_id: str | None,
    scenario_lookup: dict[tuple[str, date], str],
) -> dict[str, Any]:
    leg_key = candidate_charger_id or "destination"
    route_snapshot_id = stable_id(
        run_id, "route-snapshot", f"{trip['trip_id']}:{leg_key}"
    )
    route_snapshot_at = requested_at + timedelta(seconds=int(rng.integers(1, 5)))
    scenario = scenario_lookup.get(
        (destination_zone_id, route_snapshot_at.date()), "normal_weekday"
    )
    straight_distance = haversine_km(
        float(trip["start_latitude"]),
        float(trip["start_longitude"]),
        destination_latitude,
        destination_longitude,
    )
    road_factor = float(rng.uniform(1.14, 1.38))
    distance_km = max(0.5, straight_distance * road_factor)
    steep_route = bool(rng.random() < config.synthetic.route_energy.steep_route_probability)
    route_quality = str(rng.choice(("high", "medium", "fallback"), p=(0.78, 0.18, 0.04)))
    elevation_missing = bool(
        route_quality == "fallback"
        or rng.random() < config.synthetic.route_energy.missing_elevation_probability
    )
    weather_missing = bool(
        rng.random() < config.synthetic.route_energy.missing_weather_probability
    )
    morphology = _route_morphology(
        rng, distance_km, scenario, steep_route, elevation_missing
    )
    peak_multiplier = 1 + 0.62 * _traffic_peak(route_snapshot_at.hour) * float(
        morphology["urban_fraction"]
    )
    traffic_delay_ratio = float(
        np.clip(
            peak_multiplier * float(morphology["scenario_traffic_multiplier"])
            + rng.normal(0, 0.045),
            1.0,
            2.75,
        )
    )
    normal_duration = float(morphology["normal_duration_minutes"])
    traffic_duration = normal_duration * traffic_delay_ratio
    stop_rate = distance_km * (
        0.68 * float(morphology["urban_fraction"])
        + 0.045 * float(morphology["highway_fraction"])
    ) * min(1.75, traffic_delay_ratio)
    full_stops = int(rng.poisson(max(0.05, stop_rate)))
    weather = _public_weather(rng, route_snapshot_at, scenario, weather_missing)
    provider = (
        "deterministic_haversine_fallback"
        if route_quality == "fallback"
        else "synthetic_route_provider"
    )
    route_hash = stable_hash(
        {
            "origin": [
                round(float(trip["start_latitude"]), 5),
                round(float(trip["start_longitude"]), 5),
            ],
            "destination": [round(destination_latitude, 5), round(destination_longitude, 5)],
            "distance_km": round(distance_km, 3),
            "leg_key": leg_key,
        }
    )
    return {
        "route_snapshot_id": route_snapshot_id,
        "trip_id": trip["trip_id"],
        "request_id": request_id,
        "vehicle_id": trip["vehicle_id"],
        "candidate_charger_id": candidate_charger_id,
        "leg_type": "candidate_charger" if candidate_charger_id else "destination",
        "provider": provider,
        "provider_route_id": stable_id(run_id, "provider-route", route_snapshot_id),
        "route_hash": route_hash,
        "requested_at": requested_at,
        "route_snapshot_at": route_snapshot_at,
        "expires_at": route_snapshot_at + timedelta(minutes=10),
        "origin_latitude": round(float(trip["start_latitude"]), 7),
        "origin_longitude": round(float(trip["start_longitude"]), 7),
        "destination_latitude": round(destination_latitude, 7),
        "destination_longitude": round(destination_longitude, 7),
        "distance_km": round(distance_km, 3),
        "normal_duration_minutes": round(normal_duration, 3),
        "traffic_duration_minutes": round(traffic_duration, 3),
        "traffic_delay_ratio": round(traffic_delay_ratio, 5),
        "elevation_gain_m": morphology["elevation_gain_m"],
        "elevation_loss_m": morphology["elevation_loss_m"],
        "mean_grade_percent": morphology["mean_grade_percent"],
        "maximum_grade_percent": morphology["maximum_grade_percent"],
        "urban_fraction": morphology["urban_fraction"],
        "highway_fraction": morphology["highway_fraction"],
        "estimated_full_stop_count": full_stops,
        **weather,
        "route_source_quality": route_quality,
        "elevation_source_quality": morphology["elevation_source_quality"],
        "simulation_run_id": run_id,
    }


def generate_route_snapshots(
    config: VoltEZConfig,
    run_id: str,
    requests: list[dict[str, Any]],
    trips: pd.DataFrame,
    trip_charger_options: pd.DataFrame,
    chargers: pd.DataFrame,
    vehicles: pd.DataFrame,
    zones: pd.DataFrame,
    scenario_lookup: dict[tuple[str, date], str],
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Create immutable direct/candidate route snapshots and attach their foreign keys."""

    coverage_trips, coverage_context = _generate_coverage_trips(
        config, run_id, vehicles, zones
    )
    trips_with_routes = pd.DataFrame(
        [*_records(trips), *_records(coverage_trips)], columns=TRIP_COLUMNS
    )
    options_with_routes = trip_charger_options.reset_index(drop=True).copy()
    trips_with_routes["direct_route_snapshot_id"] = pd.NA
    options_with_routes["route_snapshot_id"] = pd.NA
    if not config.synthetic.route_energy.enabled or trips.empty:
        return (
            pd.DataFrame(columns=ROUTE_SNAPSHOT_COLUMNS),
            trips_with_routes,
            options_with_routes,
        )

    rng = named_rng(config.project.seed, "route-energy-public-route-snapshots-v1")
    requests_by_trip = {
        str(request["trip_id"]): request for request in requests if request.get("trip_id")
    }
    charger_lookup = {
        str(charger["charger_id"]): charger for charger in _records(chargers)
    }
    option_indices_by_trip: dict[str, list[int]] = {}
    option_records = _records(options_with_routes)
    for index, option in enumerate(option_records):
        option_indices_by_trip.setdefault(str(option["trip_id"]), []).append(index)

    rows: list[dict[str, Any]] = []
    for trip_index, trip_record in enumerate(_records(trips_with_routes)):
        trip_id = str(trip_record["trip_id"])
        request = requests_by_trip.get(trip_id)
        if request is None:
            requested_at, destination_zone_id = coverage_context[trip_id]
            request_id = None
        else:
            requested_at = pd.Timestamp(request["requested_at"])
            destination_zone_id = str(request["zone_id"])
            request_id = str(request["request_id"])
        direct = _build_route_snapshot(
            config=config,
            rng=rng,
            run_id=run_id,
            trip=trip_record,
            request_id=request_id,
            requested_at=requested_at,
            destination_latitude=float(trip_record["destination_latitude"]),
            destination_longitude=float(trip_record["destination_longitude"]),
            destination_zone_id=destination_zone_id,
            candidate_charger_id=None,
            scenario_lookup=scenario_lookup,
        )
        rows.append(direct)
        trips_with_routes.at[trip_index, "direct_route_snapshot_id"] = direct[
            "route_snapshot_id"
        ]

        option_indices = sorted(
            option_indices_by_trip.get(trip_id, []),
            key=lambda index: int(option_records[index]["rank"]),
        )[: config.synthetic.route_energy.maximum_candidate_snapshots_per_trip]
        for option_index in option_indices:
            charger_id = str(options_with_routes.at[option_index, "charger_id"])
            charger = charger_lookup[charger_id]
            candidate = _build_route_snapshot(
                config=config,
                rng=rng,
                run_id=run_id,
                trip=trip_record,
                request_id=request_id,
                requested_at=requested_at,
                destination_latitude=float(charger["latitude"]),
                destination_longitude=float(charger["longitude"]),
                destination_zone_id=str(charger["zone_id"]),
                candidate_charger_id=charger_id,
                scenario_lookup=scenario_lookup,
            )
            rows.append(candidate)
            options_with_routes.at[option_index, "route_snapshot_id"] = candidate[
                "route_snapshot_id"
            ]

    snapshots = pd.DataFrame(rows, columns=ROUTE_SNAPSHOT_COLUMNS)
    return snapshots, trips_with_routes, options_with_routes
