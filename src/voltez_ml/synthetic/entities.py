"""Static Pune supply and anonymized driver population generation."""

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


def generate_static_entities(config: VoltEZConfig, run_id: str) -> dict[str, pd.DataFrame]:
    """Generate stable geography, host supply, ports, and anonymized vehicle profiles."""

    settings = config.synthetic
    zone_rng = named_rng(config.project.seed, "static-zones")
    supply_rng = named_rng(config.project.seed, "static-supply")
    driver_rng = named_rng(config.project.seed, "static-drivers")

    zones: list[dict[str, Any]] = []
    zone_latent: list[dict[str, Any]] = []
    for index in range(settings.zone_count):
        name, latitude, longitude, zone_type = _zone_source(index)
        zone_id = stable_id(run_id, "zone", index)
        zones.append(
            {
                "zone_id": zone_id,
                "city": config.project.city,
                "name": name,
                "centroid_latitude": latitude,
                "centroid_longitude": longitude,
                "zone_type": zone_type,
                "timezone": config.project.timezone,
                "active": True,
                "simulation_run_id": run_id,
            }
        )
        zone_latent.append(
            {
                "zone_id": zone_id,
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
                "current_type": current_type,
                "simulation_run_id": run_id,
            }
            for code, display_name, current_type in CONNECTORS
        ]
    )
    connector_ids = connector_types.set_index("code")["connector_type_id"].to_dict()

    businesses: list[dict[str, Any]] = []
    business_hours: list[dict[str, Any]] = []
    for index in range(settings.business_count):
        zone = (
            zones[index % len(zones)]
            if index < len(zones)
            else zones[int(supply_rng.integers(len(zones)))]
        )
        category = str(supply_rng.choice(BUSINESS_CATEGORIES))
        business_id = stable_id(run_id, "business", index)
        latitude = float(zone["centroid_latitude"] + supply_rng.normal(0, 0.004))
        longitude = float(zone["centroid_longitude"] + supply_rng.normal(0, 0.004))
        businesses.append(
            {
                "business_id": business_id,
                "owner_training_id": stable_id(run_id, "host", index),
                "zone_id": zone["zone_id"],
                "name": f"Synthetic {category.replace('_', ' ').title()} {index + 1}",
                "category": category,
                "latitude": latitude,
                "longitude": longitude,
                "verification_status": "verified",
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
                    "open_minute": open_minute,
                    "close_minute": close_minute,
                    "is_closed": False,
                    "simulation_run_id": run_id,
                }
            )

    chargers: list[dict[str, Any]] = []
    ports: list[dict[str, Any]] = []
    parking_spaces: list[dict[str, Any]] = []
    business_by_id = {business["business_id"]: business for business in businesses}
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
        base_price = round(float(supply_rng.uniform(12, 28)), 2)
        chargers.append(
            {
                "charger_id": charger_id,
                "business_id": business_id,
                "zone_id": business["zone_id"],
                "name": f"VoltEZ Synthetic Charger {index + 1}",
                "latitude": business["latitude"],
                "longitude": business["longitude"],
                "access_type": str(
                    supply_rng.choice(
                        ("public", "customer_only", "controlled"), p=(0.62, 0.28, 0.10)
                    )
                ),
                "base_price_per_kwh": base_price,
                "currency": "INR",
                "listing_status": "active",
                "verification_status": "verified",
                "simulation_run_id": run_id,
            }
        )
        number_of_ports = int(
            supply_rng.integers(
                settings.supply.minimum_ports_per_charger,
                settings.supply.maximum_ports_per_charger + 1,
            )
        )
        for port_number in range(number_of_ports):
            parking_space_id = stable_id(run_id, "parking-space", f"{index}:{port_number}")
            connector_code = str(supply_rng.choice(connector_codes, p=connector_probabilities))
            current_type = next(item[2] for item in CONNECTORS if item[0] == connector_code)
            power_options = (
                (3.3, 7.2, 11.0, 22.0) if current_type == "AC" else (25.0, 30.0, 50.0, 60.0)
            )
            ports.append(
                {
                    "port_id": stable_id(run_id, "port", f"{index}:{port_number}"),
                    "parking_space_id": parking_space_id,
                    "charger_id": charger_id,
                    "business_id": business_id,
                    "zone_id": business["zone_id"],
                    "connector_type_id": connector_ids[connector_code],
                    "connector_code": connector_code,
                    "max_power_kw": float(supply_rng.choice(power_options)),
                    "current_type": current_type,
                    "operational_status": "unknown",
                    "simulation_run_id": run_id,
                }
            )
            parking_spaces.append(
                {
                    "parking_space_id": parking_space_id,
                    "business_id": business_id,
                    "label": f"EV-{index + 1}-{port_number + 1}",
                    "accessibility_type": "standard",
                    "vehicle_class_limit": "any",
                    "status": "active",
                    "simulation_run_id": run_id,
                }
            )

    availability_windows: list[dict[str, Any]] = []
    start_date = settings.start_date
    hours_lookup = {(row["business_id"], row["day_of_week"]): row for row in business_hours}
    for port in ports:
        for day_offset in range(settings.days):
            local_date = start_date + timedelta(days=day_offset)
            hours = hours_lookup[(port["business_id"], local_date.weekday())]
            start_at = pd.Timestamp(local_date, tz=config.project.timezone) + timedelta(
                minutes=hours["open_minute"]
            )
            end_at = pd.Timestamp(local_date, tz=config.project.timezone) + timedelta(
                minutes=hours["close_minute"]
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
                    "simulation_run_id": run_id,
                }
            )

    driver_profiles: list[dict[str, Any]] = []
    vehicles: list[dict[str, Any]] = []
    vehicle_connectors: list[dict[str, Any]] = []
    for index in range(settings.driver_count):
        driver_id = stable_id(run_id, "driver", index)
        vehicle_id = stable_id(run_id, "vehicle", index)
        vehicle_class = str(driver_rng.choice(VEHICLE_CLASSES))
        if vehicle_class == "two_wheeler":
            battery_kwh, range_km = (
                float(driver_rng.uniform(2.5, 5.5)),
                float(driver_rng.uniform(70, 150)),
            )
            connector_code = "bharat_ac_001"
            max_ac_kw, max_dc_kw = 3.3, 0.0
        elif vehicle_class == "three_wheeler":
            battery_kwh, range_km = (
                float(driver_rng.uniform(7, 15)),
                float(driver_rng.uniform(90, 180)),
            )
            connector_code = str(driver_rng.choice(("bharat_ac_001", "bharat_dc_001")))
            max_ac_kw, max_dc_kw = 7.2, 15.0
        else:
            battery_kwh, range_km = (
                float(driver_rng.uniform(28, 82)),
                float(driver_rng.uniform(220, 520)),
            )
            connector_code = str(
                driver_rng.choice(("type_2", "ccs2", "chademo"), p=(0.38, 0.56, 0.06))
            )
            max_ac_kw, max_dc_kw = (
                float(driver_rng.choice((7.2, 11.0, 22.0))),
                float(driver_rng.choice((30.0, 50.0, 60.0))),
            )
        home_zone_id = zones[int(driver_rng.integers(len(zones)))]["zone_id"]
        driver_profiles.append(
            {
                "training_user_id": driver_id,
                "home_zone_id": home_zone_id,
                "simulation_run_id": run_id,
            }
        )
        vehicles.append(
            {
                "vehicle_id": vehicle_id,
                "training_user_id": driver_id,
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
                "connector_code": connector_code,
                "is_preferred": True,
                "simulation_run_id": run_id,
            }
        )

    frames = {
        "zones": pd.DataFrame(zones),
        "qa_latent_zones": pd.DataFrame(zone_latent),
        "connector_types": connector_types,
        "businesses": pd.DataFrame(businesses),
        "business_hours": pd.DataFrame(business_hours),
        "chargers": pd.DataFrame(chargers),
        "charger_ports": pd.DataFrame(ports),
        "parking_spaces": pd.DataFrame(parking_spaces),
        "availability_windows": pd.DataFrame(availability_windows),
        "driver_profiles": pd.DataFrame(driver_profiles),
        "vehicles": pd.DataFrame(vehicles),
        "vehicle_connectors": pd.DataFrame(vehicle_connectors),
    }
    return {name: frame.reset_index(drop=True) for name, frame in frames.items()}
