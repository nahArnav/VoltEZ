"""
VoltEZ Demo Seed Script

Creates deterministic demo data for hackathon presentations.
Run from the backend directory:
    python -m scripts.seed_demo
Or from project root:
    cd backend && python ../../scripts/seed_demo.py

Prerequisites:
    - PostgreSQL with PostGIS running (docker compose up -d)
    - Alembic migrations applied (alembic upgrade head)
"""

import asyncio
import os
import random
import sys
from datetime import UTC, datetime, timedelta

# Add the backend directory to the path so we can import app modules
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from sqlalchemy import select, text

from app.core.security import hash_password
from app.db.session import AsyncSessionLocal
from app.schemas.enums import BookingStatus, UserRole
from database.models import (
    Booking,
    Business,
    BusinessHours,
    Charger,
    ChargerAvailability,
    ChargerPort,
    ChargerStatusEvent,
    ChargingSession,
    ConnectorType,
    DemandHistory,
    User,
    Vehicle,
    Zone,
)

# Seed-time randomness is intentionally fixed so screenshots, ML fixtures, and
# demo rehearsals are reproducible across machines.
random.seed(42)

# --- Pune Coordinates for Demo ---
# Approximate center: 18.5204° N, 73.8567° E
PUNE_LOCATIONS = {
    "phoenix_mall": {
        "lat": 18.5623,
        "lng": 73.9166,
        "name": "Phoenix Marketcity",
        "category": "mall",
    },
    "eon_it_park": {"lat": 18.5535, "lng": 73.9435, "name": "EON IT Park", "category": "office"},
    "blue_ridge": {
        "lat": 18.5880,
        "lng": 73.9286,
        "name": "Blue Ridge Society",
        "category": "apartment",
    },
    "kalyani_nagar": {
        "lat": 18.5471,
        "lng": 73.9026,
        "name": "Kalyani Nagar Plaza",
        "category": "mall",
    },
    "magarpatta_city": {
        "lat": 18.5159,
        "lng": 73.9272,
        "name": "Magarpatta Cybercity",
        "category": "office",
    },
    "viman_nagar": {
        "lat": 18.5679,
        "lng": 73.9143,
        "name": "Viman Nagar Hub",
        "category": "office",
    },
    "koregaon_park": {
        "lat": 18.5362,
        "lng": 73.8939,
        "name": "Koregaon Park Arcade",
        "category": "mall",
    },
    "fc_road": {"lat": 18.5183, "lng": 73.8441, "name": "FC Road Hub", "category": "retail"},
    "baner_balewadi": {
        "lat": 18.5590,
        "lng": 73.7868,
        "name": "Baner Highstreet",
        "category": "retail",
    },
    "hinjewadi_ph1": {
        "lat": 18.5913,
        "lng": 73.7389,
        "name": "Hinjewadi Phase 1",
        "category": "office",
    },
    "hinjewadi_ph2": {
        "lat": 18.5955,
        "lng": 73.7196,
        "name": "Hinjewadi Phase 2",
        "category": "office",
    },
    "hinjewadi_ph3": {
        "lat": 18.5828,
        "lng": 73.7029,
        "name": "Hinjewadi Phase 3",
        "category": "office",
    },
    "wakad": {"lat": 18.5987, "lng": 73.7688, "name": "Wakad Junction", "category": "apartment"},
    "pimple_saudagar": {
        "lat": 18.5932,
        "lng": 73.7937,
        "name": "Pimple Saudagar Square",
        "category": "retail",
    },
    "aundh": {"lat": 18.5577, "lng": 73.8078, "name": "Aundh IT Park", "category": "office"},
    "shivaji_nagar": {
        "lat": 18.5314,
        "lng": 73.8446,
        "name": "Shivaji Nagar Metro",
        "category": "transit",
    },
    "swargate": {
        "lat": 18.5018,
        "lng": 73.8586,
        "name": "Swargate Bus Stand",
        "category": "transit",
    },
    "camp": {"lat": 18.5135, "lng": 73.8767, "name": "Camp Cantonment", "category": "retail"},
    "hadapsar": {
        "lat": 18.5089,
        "lng": 73.9259,
        "name": "Hadapsar Industrial Area",
        "category": "office",
    },
    "kharadi": {"lat": 18.5515, "lng": 73.9348, "name": "Kharadi Bypass", "category": "retail"},
}

# Charger configurations matching real Indian EV ecosystem
CHARGER_CONFIGS = [
    # Phoenix Mall chargers - high-traffic, mixed types
    {
        "business": "phoenix_mall",
        "name": "Phoenix Fast Charger A1",
        "power_kw": 50.0,
        "base_price": 18.0,
        "ports": [("CCS2", 50.0), ("CHAdeMO", 50.0)],
        "reliability": 0.94,
    },
    {
        "business": "phoenix_mall",
        "name": "Phoenix Fast Charger A2",
        "power_kw": 50.0,
        "base_price": 18.0,
        "ports": [("CCS2", 50.0)],
        "reliability": 0.91,
    },
    {
        "business": "phoenix_mall",
        "name": "Phoenix AC Charger B1",
        "power_kw": 7.4,
        "base_price": 12.0,
        "ports": [("Type2", 7.4), ("Type2", 7.4)],
        "reliability": 0.88,
    },
    {
        "business": "phoenix_mall",
        "name": "Phoenix AC Charger B2",
        "power_kw": 22.0,
        "base_price": 14.0,
        "ports": [("Type2", 22.0)],
        "reliability": 0.95,
    },
    # EON IT Park chargers - office hours focused
    {
        "business": "eon_it_park",
        "name": "EON DC Fast 1",
        "power_kw": 60.0,
        "base_price": 16.0,
        "ports": [("CCS2", 60.0)],
        "reliability": 0.92,
    },
    {
        "business": "eon_it_park",
        "name": "EON DC Fast 2",
        "power_kw": 60.0,
        "base_price": 16.0,
        "ports": [("CCS2", 60.0), ("CHAdeMO", 50.0)],
        "reliability": 0.89,
    },
    {
        "business": "eon_it_park",
        "name": "EON AC Slow 1",
        "power_kw": 7.4,
        "base_price": 10.0,
        "ports": [("Type2", 7.4), ("Type2", 7.4)],
        "reliability": 0.96,
    },
    {
        "business": "eon_it_park",
        "name": "EON AC Slow 2",
        "power_kw": 7.4,
        "base_price": 10.0,
        "ports": [("Type2", 7.4)],
        "reliability": 0.85,
    },
    # Blue Ridge apartment chargers
    {
        "business": "blue_ridge",
        "name": "Blue Ridge Charger 1",
        "power_kw": 22.0,
        "base_price": 11.0,
        "ports": [("Type2", 22.0), ("CCS2", 22.0)],
        "reliability": 0.90,
    },
    {
        "business": "blue_ridge",
        "name": "Blue Ridge Charger 2",
        "power_kw": 7.4,
        "base_price": 9.0,
        "ports": [("Type2", 7.4)],
        "reliability": 0.93,
    },
    # Intentionally UNRELIABLE charger (for demo: shows low reliability in recommendations)
    {
        "business": "blue_ridge",
        "name": "Blue Ridge Old Charger X",
        "power_kw": 3.3,
        "base_price": 8.0,
        "ports": [("Type1", 3.3)],
        "reliability": 0.25,
    },  # Low reliability!
    # Intentionally INCOMPATIBLE-ONLY charger (CHAdeMO only - won't match most modern Indian EVs with CCS2)
    {
        "business": "phoenix_mall",
        "name": "Phoenix Legacy Charger Z",
        "power_kw": 50.0,
        "base_price": 15.0,
        "ports": [("CHAdeMO", 50.0)],
        "reliability": 0.80,
    },
]

# Auto-generate basic chargers for the remaining 17 hubs
for loc_key in list(PUNE_LOCATIONS.keys())[3:]:
    # Each new hub gets a Fast DC charger and an AC charger
    CHARGER_CONFIGS.append(
        {
            "business": loc_key,
            "name": f"{PUNE_LOCATIONS[loc_key]['name']} DC Fast",
            "power_kw": 50.0,
            "base_price": random.choice([15.0, 16.0, 18.0, 20.0]),
            "ports": [("CCS2", 50.0), ("Type2", 22.0)],
            "reliability": random.uniform(0.80, 0.99),
        }
    )
    CHARGER_CONFIGS.append(
        {
            "business": loc_key,
            "name": f"{PUNE_LOCATIONS[loc_key]['name']} AC Slow",
            "power_kw": 7.4,
            "base_price": random.choice([8.0, 10.0, 12.0]),
            "ports": [("Type2", 7.4), ("Type2", 7.4)],
            "reliability": random.uniform(0.85, 0.99),
        }
    )

# Demo vehicles matching Indian EV market
VEHICLES = [
    {
        "make": "Tata",
        "model": "Nexon EV Max",
        "battery_kwh": 40.5,
        "connectors": ["CCS2", "Type2"],
        "max_ac_kw": 7.4,
        "max_dc_kw": 50.0,
        "range_km": 437,
    },
    {
        "make": "MG",
        "model": "ZS EV",
        "battery_kwh": 50.3,
        "connectors": ["CCS2", "Type2"],
        "max_ac_kw": 7.4,
        "max_dc_kw": 76.0,
        "range_km": 461,
    },
    {
        "make": "Hyundai",
        "model": "Ioniq 5",
        "battery_kwh": 72.6,
        "connectors": ["CCS2"],
        "max_ac_kw": 11.0,
        "max_dc_kw": 220.0,
        "range_km": 481,
    },
]


def connector_lookup_for_seed(display_name: str, normalized_connectors: dict[str, ConnectorType]) -> int:
    """Resolve a human-friendly connector label to the catalog primary key."""
    key = display_name.lower().replace(" ", "").replace("_", "")
    connector = normalized_connectors.get(key)
    if connector is None:
        raise RuntimeError(f"Connector catalogue has no entry for {display_name!r}")
    return connector.id


async def seed():
    """Create all demo data in a clean database."""
    async with AsyncSessionLocal() as session:
        async with session.begin():
            # Check if data already exists
            result = await session.execute(text("SELECT COUNT(*) FROM users"))
            count = result.scalar() or 0
            if count > 0:
                print("⚠️  Database already has data. Skipping seed.")
                print("   To re-seed, drop and recreate the database, then run migrations.")
                return

            print("🌱 Seeding VoltEZ demo data...")

            # --- 1. Create Users ---
            print("  → Creating users...")

            owner = User(
                name="Priya Sharma",
                email="priya@voltez.demo",
                phone="+919876543210",
                password_hash=hash_password("owner123"),
                role=UserRole.OWNER,
                verification_status="verified",
            )
            session.add(owner)

            admin = User(
                name="Admin User",
                email="admin@voltez.demo",
                password_hash=hash_password("admin123"),
                role=UserRole.ADMIN,
                verification_status="verified",
            )
            session.add(admin)

            drivers = []
            driver_names = [
                ("Rahul Verma", "rahul@voltez.demo", "+919876543211"),
                ("Ananya Patel", "ananya@voltez.demo", "+919876543212"),
                ("Vikram Singh", "vikram@voltez.demo", "+919876543213"),
            ]
            for name, email, phone in driver_names:
                driver = User(
                    name=name,
                    email=email,
                    phone=phone,
                    password_hash=hash_password("driver123"),
                    role=UserRole.DRIVER,
                    verification_status="verified",
                )
                session.add(driver)
                drivers.append(driver)

            await session.flush()  # Get IDs
            print(f"    ✓ Created {len(drivers)} drivers, 1 owner, 1 admin")

            # --- 2. Load reference data and create vehicles ---
            print("  → Loading connector catalogue and Pune zone...")
            connector_rows = await session.execute(select(ConnectorType))
            connectors = {connector.code: connector for connector in connector_rows.scalars().all()}
            normalized_connectors = {
                code.lower().replace("_", ""): connector for code, connector in connectors.items()
            }
            required_connectors = {connector for vehicle in VEHICLES for connector in vehicle["connectors"]}
            connector_lookup = {
                code: normalized_connectors.get(code.lower().replace(" ", "").replace("_", ""))
                for code in required_connectors
            }
            missing_connectors = [code for code, connector in connector_lookup.items() if connector is None]
            if missing_connectors:
                raise RuntimeError(
                    "Connector catalogue is incomplete; run Alembic migrations first. "
                    f"Missing: {', '.join(sorted(missing_connectors))}"
                )

            zone_result = await session.execute(
                select(Zone).where(Zone.city == "Pune", Zone.active.is_(True)).limit(1)
            )
            pune_zone = zone_result.scalar_one_or_none()
            if pune_zone is None:
                pune_zone = Zone(
                    city="Pune",
                    name="Pune Central",
                    h3_index="voltez-pune-central-seed",
                    centroid="SRID=4326;POINT(73.8567 18.5204)",
                    timezone="Asia/Kolkata",
                    active=True,
                    zone_type="commercial",
                )
                session.add(pune_zone)
                await session.flush()

            # --- 3. Create Vehicles ---
            print("  → Creating vehicles...")
            vehicles = []
            for _i, (driver, v) in enumerate(zip(drivers, VEHICLES)):
                vehicle = Vehicle(
                    user_id=driver.id,
                    make=v["make"],
                    model=v["model"],
                    vehicle_class="car",
                    battery_kwh=v["battery_kwh"],
                    max_ac_kw=v["max_ac_kw"],
                    max_dc_kw=v["max_dc_kw"],
                    estimated_range_km=v["range_km"],
                    efficiency_wh_per_km=round(v["battery_kwh"] * 1000 / v["range_km"], 2),
                )
                vehicle.connector_types = [connector_lookup[code] for code in v["connectors"]]
                session.add(vehicle)
                vehicles.append(vehicle)

            await session.flush()
            print(f"    ✓ Created {len(vehicles)} vehicles")

            # --- 4. Create Businesses ---
            print("  → Creating businesses...")
            businesses = {}
            for key, loc in PUNE_LOCATIONS.items():
                biz = Business(
                    owner_id=owner.id,
                    zone_id=pune_zone.id,
                    name=loc["name"],
                    category=loc["category"],
                    address_text=f"{loc['name']}, Pune, Maharashtra, India",
                    location=f"SRID=4326;POINT({loc['lng']} {loc['lat']})",
                    timezone="Asia/Kolkata",
                    verification_status="verified",
                )
                session.add(biz)
                businesses[key] = biz

            await session.flush()
            print(f"    ✓ Created {len(businesses)} businesses")

            # Store recurring opening hours in the normalized table rather
            # than the removed JSON `opening_hours` column.
            for business in businesses.values():
                for day_of_week in range(7):
                    session.add(
                        BusinessHours(
                            business_id=business.id,
                            day_of_week=day_of_week,
                            open_local_time=datetime.strptime("08:00", "%H:%M").time(),
                            close_local_time=datetime.strptime("22:00", "%H:%M").time(),
                            is_closed=False,
                        )
                    )
            await session.flush()

            # --- 5. Create Chargers and Ports ---
            print("  → Creating chargers and ports...")
            all_ports = []
            charger_count = 0
            for cfg in CHARGER_CONFIGS:
                biz = businesses[cfg["business"]]
                loc = PUNE_LOCATIONS[cfg["business"]]

                # Slight offset from business location for each charger
                offset_lat = random.uniform(-0.001, 0.001)
                offset_lng = random.uniform(-0.001, 0.001)

                charger = Charger(
                    business_id=biz.id,
                    name=cfg["name"],
                    location=f"SRID=4326;POINT({loc['lng'] + offset_lng} {loc['lat'] + offset_lat})",
                    charger_type="DC" if cfg["power_kw"] > 22 else "AC",
                    power_kw=cfg["power_kw"],
                    access_type="public",
                    price_per_kwh=cfg["base_price"],
                    status="available",
                    verification_status="verified",
                    reliability_score=round(cfg["reliability"] * 100, 2),
                    address_text=f"{loc['name']}, Pune, Maharashtra, India",
                )
                session.add(charger)
                await session.flush()

                for port_number, (connector_type, max_power) in enumerate(cfg["ports"], start=1):
                    port = ChargerPort(
                        charger_id=charger.id,
                        connector_type_id=connector_lookup_for_seed(
                            connector_type, normalized_connectors
                        ),
                        port_number=port_number,
                        max_power_kw=max_power,
                        is_active=True,
                    )
                    session.add(port)
                    all_ports.append(port)

                charger_count += 1

            await session.flush()
            print(f"    ✓ Created {charger_count} chargers with {len(all_ports)} ports")

            # --- 6. Create recurring availability schedules ---
            print("  → Creating charger availability schedules...")
            now = datetime.now(UTC)
            window_count = 0
            for port in all_ports:
                # The current schema stores weekly local-time availability.
                # One row per day is enough to cover the next seven days.
                for day_of_week in range(7):
                    session.add(
                        ChargerAvailability(
                            charger_port_id=port.id,
                            day_of_week=day_of_week,
                            start_local_time=datetime.strptime("08:00", "%H:%M").time(),
                            end_local_time=datetime.strptime("22:00", "%H:%M").time(),
                            is_unavailable=False,
                        )
                    )
                    window_count += 1

            await session.flush()
            print(f"    ✓ Created {window_count} availability windows")

            # --- 6. Create Charger Status Events ---
            print("  → Creating charger status events...")
            status_count = 0
            for port in all_ports[:8]:  # Status events for first 8 ports
                event = ChargerStatusEvent(
                    charger_id=port.charger_id,
                    port_id=port.id,
                    status="available",
                    source="OWNER",
                    confidence=0.85,
                    observed_at=now - timedelta(hours=1),
                )
                session.add(event)
                status_count += 1

            await session.flush()
            print(f"    ✓ Created {status_count} status events")

            # --- 7. Create Synthetic Historical Bookings ---
            print("  → Creating historical bookings and sessions...")
            historical_booking_count = 0
            for _i in range(50):
                # Random time in the last 30 days
                days_ago = random.randint(1, 30)
                book_time = now - timedelta(days=days_ago, hours=random.randint(0, 23))
                start_time = book_time + timedelta(minutes=random.randint(5, 60))
                end_time = start_time + timedelta(minutes=random.randint(20, 120))

                # Pick a random driver and port
                driver = random.choice(drivers)
                port = random.choice(all_ports)

                b = Booking(
                    user_id=driver.id,
                    charger_port_id=port.id,
                    start_at=start_time,
                    end_at=end_time,
                    status=BookingStatus.COMPLETED.value,
                    estimated_amount=round(random.uniform(150.0, 700.0), 2),
                    quoted_price_per_kwh=round(random.uniform(8.0, 20.0), 2),
                    created_at=book_time,
                )
                session.add(b)
                await session.flush()

                # Associated charging session
                cs = ChargingSession(
                    charger_port_id=port.id,
                    user_id=driver.id,
                    booking_id=b.id,
                    reserved_at=book_time,
                    started_at=start_time,
                    ended_at=end_time,
                    energy_kwh=round(random.uniform(10.0, 45.0), 2),
                    amount=round(random.uniform(150.0, 700.0), 2),
                    status="completed",
                )
                session.add(cs)
                historical_booking_count += 1

            await session.flush()
            print(f"    ✓ Created {historical_booking_count} historical bookings")

            # --- 8. Create 30 Days of Synthetic Demand History ---
            print("  → Creating 30 days of demand history...")
            demand_count = 0
            for day_offset in range(30):
                day = now - timedelta(days=day_offset)
                for hour in range(6, 24):  # 6 AM to midnight
                    # Simulate realistic demand patterns
                    is_weekend = day.weekday() >= 5
                    base_demand = 3 if is_weekend else 5

                    # Peak hours: 9-11 AM, 5-8 PM
                    if hour in (9, 10, 11):
                        base_demand += 4
                    elif hour in (17, 18, 19, 20):
                        base_demand += 6
                    # Off-peak: 2-4 PM (this is where the business opportunity is!)
                    elif hour in (14, 15, 16):
                        base_demand += 1

                    demand = max(0, base_demand + random.randint(-2, 3))
                    active_sessions = min(demand, max(0, len(all_ports) // 4 + random.randint(-2, 2)))
                    queued_vehicles = max(0, demand - active_sessions)

                    bucket_time = day.replace(hour=hour, minute=0, second=0, microsecond=0)

                    dh = DemandHistory(
                        zone_id=pune_zone.id,
                        timestamp=bucket_time,
                        demand_level=float(demand),
                        active_sessions=active_sessions,
                        queued_vehicles=queued_vehicles,
                    )
                    session.add(dh)
                    demand_count += 1

            await session.flush()
            print(f"    ✓ Created {demand_count} demand history records")

            print("\n✅ Demo seed complete!")
            print("\n📋 Demo Credentials:")
            print("   Owner:  priya@voltez.demo / owner123")
            print("   Admin:  admin@voltez.demo / admin123")
            print("   Driver: rahul@voltez.demo / driver123")
            print("   Driver: ananya@voltez.demo / driver123")
            print("   Driver: vikram@voltez.demo / driver123")
            print("\n📊 Summary:")
            print(f"   Users: {len(drivers) + 2}")
            print(f"   Vehicles: {len(vehicles)}")
            print(f"   Businesses: {len(businesses)}")
            print(f"   Chargers: {charger_count}")
            print(f"   Ports: {len(all_ports)}")
            print(f"   Availability Windows: {window_count}")
            print(f"   Demand History Records: {demand_count}")
            print("\n⚠️  Special Demo Chargers:")
            print("   'Blue Ridge Old Charger X' → Intentionally LOW reliability (0.25)")
            print(
                "   'Phoenix Legacy Charger Z' → CHAdeMO only (incompatible with most modern EVs)"
            )


if __name__ == "__main__":
    random.seed(42)  # Deterministic seed for reproducible demo data
    asyncio.run(seed())
