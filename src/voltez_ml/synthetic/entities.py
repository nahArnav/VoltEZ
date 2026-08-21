"""Static Pune application entities for schema v1.1 synthetic runs."""

from __future__ import annotations

from datetime import timedelta
from typing import Any

import numpy as np
import pandas as pd

from voltez_ml.config import VoltEZConfig
from voltez_ml.synthetic.randomness import named_rng, stable_id

PUNE_AREAS: tuple[tuple[str, float, float, str], ...] = (
    ("Shivajinagar", 18.5308, 73.8475, "commercial"),
    ("Koregaon Park", 18.5362, 73.8940, "retail"),
    ("Kharadi", 18.5515, 73.9348, "office"),
    ("Viman Nagar", 18.5679, 73.9143, "mixed"),
    ("Hadapsar", 18.5089, 73.9259, "mixed"),
    ("Baner", 18.5590, 73.7868, "residential"),
    ("Aundh", 18.5580, 73.8075, "residential"),
    ("Hinjawadi", 18.5913, 73.7389, "office"),
    ("Wakad", 18.5993, 73.7625, "mixed"),
    ("Pimpri", 18.6298, 73.7997, "industrial"),
    ("Kothrud", 18.5074, 73.8077, "residential"),
    ("Warje", 18.4827, 73.7952, "residential"),
    ("Kondhwa", 18.4630, 73.8782, "mixed"),
    ("Bibwewadi", 18.4695, 73.8636, "residential"),
    ("Camp", 18.5132, 73.8807, "commercial"),
    ("Swargate", 18.5018, 73.8636, "transit"),
    ("Yerawada", 18.5525, 73.8797, "mixed"),
    ("Bavdhan", 18.5204, 73.7770, "residential"),
    ("Pashan", 18.5386, 73.7950, "residential"),
    ("Magarpatta", 18.5163, 73.9272, "office"),
    ("Katraj", 18.4529, 73.8652, "transit"),
    ("Dhanori", 18.5945, 73.9048, "residential"),
    ("Mundhwa", 18.5331, 73.9318, "mixed"),
    ("Balewadi", 18.5707, 73.7741, "mixed"),
)

CONNECTORS: tuple[tuple[str, str, str], ...] = (
    ("type_2", "Type 2", "AC"),
    ("ccs2", "CCS2", "DC"),
    ("chademo", "CHAdeMO", "DC"),
    ("bharat_ac_001", "Bharat AC-001", "AC"),
    ("bharat_dc_001", "Bharat DC-001", "DC"),
)

AMENITIES: tuple[tuple[str, str, str], ...] = (
    ("cafe", "Cafe", "food"),
    ("restroom", "Restroom", "comfort"),
    ("wifi", "Wi-Fi", "connectivity"),
    ("shopping", "Shopping", "retail"),
    ("accessible_parking", "Accessible parking", "accessibility"),
)

BUSINESS_CATEGORIES = ("cafe", "mall", "office", "hotel", "fuel_station", "residential")
VEHICLE_CLASSES = ("car", "car", "car", "two_wheeler", "three_wheeler", "van")


def _zone_source(index: int) -> tuple[str, float, float, str]:
    if index < len(PUNE_AREAS):
        return PUNE_AREAS[index]
    ring = index - len(PUNE_AREAS) + 1
    row, column = divmod(ring, 6)
    return (
        f"Pune Synthetic Zone {ring}",
        18.5204 + (row - 2) * 0.025,
        73.8567 + (column - 2) * 0.025,
        "mixed",
    )


def _clock(minute: int) -> str:
    """Represent local wall-clock time without attaching a misleading UTC offset."""

    hour, remainder = divmod(minute, 60)
    return f"{hour:02d}:{remainder:02d}:00"


def _boundary_wkt(latitude: float, longitude: float) -> str:
    """Create a small deterministic fixture polygon around a zone centroid."""

    half_latitude = 0.010
    half_longitude = 0.012
    points = (
        (longitude - half_longitude, latitude - half_latitude),
        (longitude + half_longitude, latitude - half_latitude),
        (longitude + half_longitude, latitude + half_latitude),
        (longitude - half_longitude, latitude + half_latitude),
        (longitude - half_longitude, latitude - half_latitude),
    )
    coordinates = ", ".join(f"{lon:.6f} {lat:.6f}" for lon, lat in points)
    return f"POLYGON(({coordinates}))"


def generate_static_entities(config: VoltEZConfig, run_id: str) -> dict[str, pd.DataFrame]:
    """Generate normalized v1.1 geography, hosts, supply, users, and vehicles."""

    settings = config.synthetic
    zone_rng = named_rng(config.project.seed, "static-zones")
    supply_rng = named_rng(config.project.seed, "static-supply")
    driver_rng = named_rng(config.project.seed, "static-drivers")
    dataset_start = pd.Timestamp(settings.start_date, tz=config.project.timezone)
    dataset_end = dataset_start + timedelta(days=settings.days)

    zones: list[dict[str, Any]] = []
    zone_latent: list[dict[str, Any]] = []
    for index in range(settings.zone_count):
        name, latitude, longitude, zone_type = _zone_source(index)
        zone_id = stable_id(run_id, "zone", index)
        zones.append(
            {
                "zone_id": zone_id,
                "name": name,
                "city": config.project.city,
                "boundary_wkt": _boundary_wkt(latitude, longitude),
                "centroid_latitude": latitude,
                "centroid_longitude": longitude,
                "timezone": config.project.timezone,
                "active": True,
                "simulation_run_id": run_id,
            }
        )
        zone_latent.append(
            {
                "zone_id": zone_id,
                "zone_type": zone_type,
                "base_demand_multiplier": float(zone_rng.lognormal(mean=0.0, sigma=0.28)),
                "price_sensitivity": float(zone_rng.beta(2.5, 2.5)),
                "traffic_multiplier": float(zone_rng.uniform(0.8, 1.35)),
                "simulation_run_id": run_id,
            }
        )

    connector_types = pd.DataFrame(
        [
            {
                "connector_type_id": stable_id(run_id, "connector", code),
                "code": code,
                "display_name": display_name,
                "charging_type": charging_type,
                "simulation_run_id": run_id,
            }
            for code, display_name, charging_type in CONNECTORS
        ]
    )
    connector_ids = connector_types.set_index("code")["connector_type_id"].to_dict()

    users: list[dict[str, Any]] = []
    businesses: list[dict[str, Any]] = []
    business_hours: list[dict[str, Any]] = []
    for index in range(settings.business_count):
        zone = (
            zones[index % len(zones)]
            if index < len(zones)
            else zones[int(supply_rng.integers(len(zones)))]
        )
        category = str(supply_rng.choice(BUSINESS_CATEGORIES))
        owner_id = stable_id(run_id, "host-user", index)
        business_id = stable_id(run_id, "business", index)
        latitude = float(zone["centroid_latitude"] + supply_rng.normal(0, 0.004))
        longitude = float(zone["centroid_longitude"] + supply_rng.normal(0, 0.004))
        users.append(
            {
                "user_id": owner_id,
                "name": f"Synthetic Host {index + 1}",
                "email": f"host-{index + 1}@example.invalid",
                "phone": None,
                "password_hash": "$synthetic$disabled",
                "role": "host",
                "verification_status": "verified",
                "created_at": dataset_start,
                "simulation_run_id": run_id,
            }
        )
        businesses.append(
            {
                "business_id": business_id,
                "owner_id": owner_id,
                "name": f"Synthetic {category.replace('_', ' ').title()} {index + 1}",
                "category": category,
                "latitude": latitude,
                "longitude": longitude,
                "address": f"Synthetic fixture address {index + 1}, Pune",
                "verification_status": "verified",
                "_generation_zone_id": zone["zone_id"],
                "simulation_run_id": run_id,
            }
        )
        for day_of_week in range(7):
            weekend = day_of_week >= 5
            if category == "office":
                open_minute, close_minute = (8 * 60, 20 * 60) if not weekend else (10 * 60, 16 * 60)
            elif category in {"mall", "cafe", "hotel"}:
                open_minute, close_minute = 8 * 60, 23 * 60
            elif category == "residential":
                open_minute, close_minute = 6 * 60, 24 * 60 - 1
            else:
                open_minute, close_minute = 6 * 60, 22 * 60
            business_hours.append(
                {
                    "business_hours_id": stable_id(
                        run_id, "business-hours", f"{index}:{day_of_week}"
                    ),
                    "business_id": business_id,
                    "day_of_week": day_of_week,
                    "opens_at": _clock(open_minute),
                    "closes_at": _clock(close_minute),
                    "simulation_run_id": run_id,
                }
            )

    exception_columns = [
        "business_hour_exception_id",
        "business_id",
        "date",
        "opens_at",
        "closes_at",
        "is_closed",
        "simulation_run_id",
    ]
    business_hour_exceptions = pd.DataFrame(columns=exception_columns)

    amenities = pd.DataFrame(
        [
            {
                "amenity_id": stable_id(run_id, "amenity", code),
                "name": name,
                "category": category,
                "simulation_run_id": run_id,
            }
            for code, name, category in AMENITIES
        ]
    )
    amenity_ids = amenities["amenity_id"].astype(str).tolist()
    business_amenities: list[dict[str, Any]] = []
    business_offers: list[dict[str, Any]] = []
    for index, business in enumerate(businesses):
        selected = supply_rng.choice(
            amenity_ids,
            size=int(supply_rng.integers(1, min(4, len(amenity_ids) + 1))),
            replace=False,
        )
        for amenity_id in selected:
            business_amenities.append(
                {
                    "business_id": business["business_id"],
                    "amenity_id": str(amenity_id),
                    "simulation_run_id": run_id,
                }
            )
        if supply_rng.random() < 0.35:
            business_offers.append(
                {
                    "business_offer_id": stable_id(run_id, "business-offer", index),
                    "business_id": business["business_id"],
                    "title": "Synthetic charging-visit offer",
                    "description": "Fixture-only offer for recommendation pipeline testing",
                    "starts_at": dataset_start,
                    "ends_at": dataset_end,
                    "status": "active",
                    "simulation_run_id": run_id,
                }
            )

    chargers: list[dict[str, Any]] = []
    ports: list[dict[str, Any]] = []
    parking_spaces: list[dict[str, Any]] = []
    tariffs: list[dict[str, Any]] = []
    business_by_id = {str(business["business_id"]): business for business in businesses}
    business_ids = list(business_by_id)
    connector_codes = [connector[0] for connector in CONNECTORS]
    connector_probabilities = np.array([0.36, 0.38, 0.07, 0.11, 0.08])
    for index in range(settings.charger_count):
        business_id = (
            business_ids[index]
            if index < len(business_ids)
            else str(supply_rng.choice(business_ids))
        )
        business = business_by_id[business_id]
        charger_id = stable_id(run_id, "charger", index)
        chargers.append(
            {
                "charger_id": charger_id,
                "business_id": business_id,
                "zone_id": business["_generation_zone_id"],
                "name": f"VoltEZ Synthetic Charger {index + 1}",
                "latitude": business["latitude"],
                "longitude": business["longitude"],
                "access_type": str(
                    supply_rng.choice(
                        ("public", "customer_only", "controlled"), p=(0.62, 0.28, 0.10)
                    )
                ),
                "status": "active",
                "reliability_score": 0.5,
                "simulation_run_id": run_id,
            }
        )
        number_of_ports = int(
            supply_rng.integers(
                settings.supply.minimum_ports_per_charger,
                settings.supply.maximum_ports_per_charger + 1,
            )
        )
        for port_number in range(1, number_of_ports + 1):
            port_id = stable_id(run_id, "port", f"{index}:{port_number}")
            connector_code = str(supply_rng.choice(connector_codes, p=connector_probabilities))
            charging_type = next(item[2] for item in CONNECTORS if item[0] == connector_code)
            power_options = (
                (3.3, 7.2, 11.0, 22.0) if charging_type == "AC" else (25.0, 30.0, 50.0, 60.0)
            )
            ports.append(
                {
                    "port_id": port_id,
                    "charger_id": charger_id,
                    "connector_type_id": connector_ids[connector_code],
                    "port_number": port_number,
                    "max_power_kw": float(supply_rng.choice(power_options)),
                    "current_status": "unknown",
                    "last_seen_at": dataset_start,
                    "simulation_run_id": run_id,
                }
            )
            parking_spaces.append(
                {
                    "parking_space_id": stable_id(
                        run_id, "parking-space", f"{index}:{port_number}"
                    ),
                    "charger_id": charger_id,
                    "label": f"EV-{index + 1}-{port_number}",
                    "accessibility_type": "standard",
                    "status": "active",
                    "simulation_run_id": run_id,
                }
            )
            tariffs.append(
                {
                    "tariff_id": stable_id(run_id, "tariff", port_id),
                    "charger_id": charger_id,
                    "port_id": port_id,
                    "price_per_kwh": round(float(supply_rng.uniform(12, 28)), 2),
                    "price_per_minute": 0.0,
                    "booking_fee": round(float(supply_rng.choice((0, 0, 10, 20))), 2),
                    "starts_at": dataset_start,
                    "ends_at": dataset_end,
                    "simulation_run_id": run_id,
                }
            )

    business_hours_lookup = {
        (str(row["business_id"]), int(row["day_of_week"])): row for row in business_hours
    }
    charger_business = {
        str(charger["charger_id"]): str(charger["business_id"]) for charger in chargers
    }
    availability_windows: list[dict[str, Any]] = []
    for port in ports:
        business_id = charger_business[str(port["charger_id"])]
        for day_offset in range(settings.days):
            local_date = settings.start_date + timedelta(days=day_offset)
            hours = business_hours_lookup[(business_id, local_date.weekday())]
            opens_hour, opens_minute, _ = (int(value) for value in hours["opens_at"].split(":"))
            closes_hour, closes_minute, _ = (int(value) for value in hours["closes_at"].split(":"))
            start_at = pd.Timestamp(local_date, tz=config.project.timezone) + timedelta(
                hours=opens_hour, minutes=opens_minute
            )
            end_at = pd.Timestamp(local_date, tz=config.project.timezone) + timedelta(
                hours=closes_hour, minutes=closes_minute
            )
            availability_windows.append(
                {
                    "availability_window_id": stable_id(
                        run_id, "availability-window", f"{port['port_id']}:{local_date.isoformat()}"
                    ),
                    "port_id": port["port_id"],
                    "start_at": start_at,
                    "end_at": end_at,
                    "source": "recurring_schedule",
                    "status": "active",
                    "price_override": None,
                    "simulation_run_id": run_id,
                }
            )

    driver_profiles: list[dict[str, Any]] = []
    vehicles: list[dict[str, Any]] = []
    vehicle_connectors: list[dict[str, Any]] = []
    for index in range(settings.driver_count):
        user_id = stable_id(run_id, "driver-user", index)
        vehicle_id = stable_id(run_id, "vehicle", index)
        vehicle_class = str(driver_rng.choice(VEHICLE_CLASSES))
        if vehicle_class == "two_wheeler":
            make, model = "Synthetic Mobility", "E2W"
            battery_kwh = float(driver_rng.uniform(2.5, 5.5))
            range_km = float(driver_rng.uniform(70, 150))
            connector_code = "bharat_ac_001"
            max_ac_kw, max_dc_kw = 3.3, 0.0
        elif vehicle_class == "three_wheeler":
            make, model = "Synthetic Mobility", "E3W"
            battery_kwh = float(driver_rng.uniform(7, 15))
            range_km = float(driver_rng.uniform(90, 180))
            connector_code = str(driver_rng.choice(("bharat_ac_001", "bharat_dc_001")))
            max_ac_kw, max_dc_kw = 7.2, 15.0
        else:
            make, model = "Synthetic Auto", "EV"
            battery_kwh = float(driver_rng.uniform(28, 82))
            range_km = float(driver_rng.uniform(220, 520))
            connector_code = str(
                driver_rng.choice(("type_2", "ccs2", "chademo"), p=(0.38, 0.56, 0.06))
            )
            max_ac_kw = float(driver_rng.choice((7.2, 11.0, 22.0)))
            max_dc_kw = float(driver_rng.choice((30.0, 50.0, 60.0)))
        users.append(
            {
                "user_id": user_id,
                "name": f"Synthetic Driver {index + 1}",
                "email": f"driver-{index + 1}@example.invalid",
                "phone": None,
                "password_hash": "$synthetic$disabled",
                "role": "driver",
                "verification_status": "verified",
                "created_at": dataset_start,
                "simulation_run_id": run_id,
            }
        )
        home_zone_id = zones[int(driver_rng.integers(len(zones)))]["zone_id"]
        driver_profiles.append(
            {
                "user_id": user_id,
                "home_zone_id": home_zone_id,
                "simulation_run_id": run_id,
            }
        )
        vehicles.append(
            {
                "vehicle_id": vehicle_id,
                "user_id": user_id,
                "make": make,
                "model": model,
                "vehicle_class": vehicle_class,
                "battery_kwh": round(battery_kwh, 2),
                "max_ac_kw": max_ac_kw,
                "max_dc_kw": max_dc_kw,
                "estimated_range_km": round(range_km, 1),
                "efficiency_wh_per_km": round(battery_kwh * 1000 / range_km, 1),
                "simulation_run_id": run_id,
            }
        )
        vehicle_connectors.append(
            {
                "vehicle_id": vehicle_id,
                "connector_type_id": connector_ids[connector_code],
                "simulation_run_id": run_id,
            }
        )

    public_businesses = pd.DataFrame(businesses).drop(columns="_generation_zone_id")
    frames = {
        "users": pd.DataFrame(users),
        "zones": pd.DataFrame(zones),
        "qa_latent_zones": pd.DataFrame(zone_latent),
        "qa_latent_driver_profiles": pd.DataFrame(driver_profiles),
        "connector_types": connector_types,
        "vehicle_connectors": pd.DataFrame(vehicle_connectors),
        "vehicles": pd.DataFrame(vehicles),
        "businesses": public_businesses,
        "business_hours": pd.DataFrame(business_hours),
        "business_hour_exceptions": business_hour_exceptions,
        "amenities": amenities,
        "business_amenities": pd.DataFrame(business_amenities),
        "business_offers": pd.DataFrame(business_offers),
        "chargers": pd.DataFrame(chargers),
        "charger_ports": pd.DataFrame(ports),
        "parking_spaces": pd.DataFrame(parking_spaces),
        "availability_windows": pd.DataFrame(availability_windows),
        "tariffs": pd.DataFrame(tariffs),
    }
    return {name: frame.reset_index(drop=True) for name, frame in frames.items()}
