import asyncio
import pytest
from httpx import AsyncClient
from datetime import datetime, timezone, timedelta

# Mark this test module for asyncio
pytestmark = pytest.mark.asyncio

async def test_booking_concurrency_redis_lock(client: AsyncClient, db_session):
    """
    Test Step 2.6: Verify that concurrent bookings for the exact same port and time slot 
    result in exactly ONE success and N failures.
    """
    from app.models.user import User, UserRole
    from app.models.vehicle import Vehicle
    from app.models.business import Business
    from app.models.charger import Charger
    from app.models.charger_port import ChargerPort
    from app.core.security import hash_password

    # 1. Seed Data
    user = User(
        email="test_concur@voltez.demo", 
        password_hash=hash_password("password123"),
        name="Test Concur",
        role=UserRole.DRIVER
    )
    db_session.add(user)
    await db_session.flush()

    vehicle = Vehicle(
        user_id=user.id,
        make="Tata",
        model="Nexon",
        battery_kwh=40.5,
        connector_types=["CCS2"]
    )
    db_session.add(vehicle)
    await db_session.flush()

    business = Business(
        owner_id=user.id,
        name="Test Business",
        verification_status="verified"
    )
    db_session.add(business)
    await db_session.flush()

    charger = Charger(
        business_id=business.id,
        name="Test Charger",
        location="SRID=4326;POINT(73.8567 18.5204)",
        power_kw=50.0,
        base_price=15.0
    )
    db_session.add(charger)
    await db_session.flush()

    port = ChargerPort(
        charger_id=charger.id,
        connector_type="CCS2",
        max_power_kw=50.0,
        status="available"
    )
    db_session.add(port)
    await db_session.commit()

    # 2. Login
    login_response = await client.post(
        "/api/v1/auth/login",
        data={"username": "test_concur@voltez.demo", "password": "password123"}
    )
    assert login_response.status_code == 200
    token = login_response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 3. Setup Payload
    now = datetime.now(timezone.utc)
    start_time = now + timedelta(days=1)
    end_time = start_time + timedelta(hours=1)
    
    payload = {
        "port_id": port.id,
        "vehicle_id": vehicle.id,
        "start_at": start_time.isoformat(),
        "end_at": end_time.isoformat(),
        "total_amount": 100.0
    }

    # 3. Fire 20 concurrent requests
    num_requests = 20
    tasks = []
    for _ in range(num_requests):
        tasks.append(
            client.post("/api/v1/bookings/", json=payload, headers=headers)
        )
    
    # Run them all at the exact same time
    responses = await asyncio.gather(*tasks, return_exceptions=True)
    
    # 4. Analyze results
    success_count = 0
    conflict_count = 0
    other_errors = 0
    
    for resp in responses:
        if isinstance(resp, Exception):
            other_errors += 1
            continue
            
        status_code = getattr(resp, "status_code", None)
        if status_code in (200, 201):
            success_count += 1
        elif status_code == 409: # Conflict
            conflict_count += 1
        else:
            other_errors += 1

    # 5. Assert exactly ONE succeeded
    assert success_count == 1, f"Expected exactly 1 successful booking, got {success_count}. Conflicts: {conflict_count}, Errors: {other_errors}"
    assert conflict_count == num_requests - 1, f"Expected {num_requests - 1} conflicts, got {conflict_count}"
