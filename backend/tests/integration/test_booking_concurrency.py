from datetime import datetime, timedelta, timezone
from uuid import uuid4
from zoneinfo import ZoneInfo

import pytest


async def _auth(client, role: str) -> dict[str, str]:
    email = f"lock-{role}-{uuid4()}@example.com"
    password = "SecurePassword123!"
    assert (
        await client.post(
            "/api/v1/auth/register",
            json={"email": email, "password": password, "name": "Lock Test", "role": role},
        )
    ).status_code == 201
    login = await client.post(
        "/api/v1/auth/login", data={"username": email, "password": password}
    )
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


@pytest.mark.asyncio
async def test_booking_lock_rejects_duplicate_slot(client):
    owner = await _auth(client, "owner")
    business = await client.post(
        "/api/v1/businesses/",
        headers=owner,
        json={
            "name": "Lock Hub",
            "category": "office",
            "zone_id": "11111111-1111-4111-8111-111111111111",
            "latitude": 18.52,
            "longitude": 73.85,
        },
    )
    charger = await client.post(
        "/api/v1/chargers/",
        headers=owner,
        json={
            "business_id": business.json()["id"],
            "name": "Lock Charger",
            "charger_type": "private",
            "power_kw": 22,
            "latitude": 18.52,
            "longitude": 73.85,
        },
    )
    port = await client.post(
        f"/api/v1/chargers/{charger.json()['id']}/ports",
        headers=owner,
        json={"connector_type_id": 2, "port_number": 1, "max_power_kw": 22},
    )
    local_start = (datetime.now(ZoneInfo("Asia/Kolkata")) + timedelta(days=1)).replace(
        hour=14, minute=0, second=0, microsecond=0
    )
    start = local_start.astimezone(timezone.utc)
    availability = await client.post(
        "/api/v1/availability/",
        headers=owner,
        json={
            "charger_port_id": port.json()["id"],
            "day_of_week": local_start.weekday(),
            "start_local_time": "13:00:00",
            "end_local_time": "16:00:00",
            "is_unavailable": False,
        },
    )
    assert availability.status_code == 201, availability.text

    driver = await _auth(client, "driver")
    payload = {
        "charger_port_id": port.json()["id"],
        "start_at": start.isoformat(),
        "end_at": (start + timedelta(hours=1)).isoformat(),
    }
    first = await client.post("/api/v1/bookings/", json=payload, headers=driver)
    second = await client.post("/api/v1/bookings/", json=payload, headers=driver)
    assert first.status_code == 201, first.text
    assert second.status_code == 409, second.text
    assert second.json()["detail"] == "SLOT_UNAVAILABLE"
