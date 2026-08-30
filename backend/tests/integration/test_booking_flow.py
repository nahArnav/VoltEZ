from datetime import UTC, datetime, timedelta
from unittest.mock import patch
from uuid import uuid4
from zoneinfo import ZoneInfo

import pytest

from app.api.v1 import payments

pytestmark = pytest.mark.integration


async def _register_and_login(client, role: str) -> dict[str, str]:
    password = "SecurePassword123!"
    email = f"{role}-{uuid4()}@example.com"
    response = await client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": role.title(), "role": role},
    )
    assert response.status_code == 201, response.text
    response = await client.post(
        "/api/v1/auth/login",
        data={"username": email, "password": password},
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


@pytest.mark.asyncio
async def test_full_booking_lifecycle(client):
    owner_headers = await _register_and_login(client, "owner")
    business = await client.post(
        "/api/v1/businesses/",
        headers=owner_headers,
        json={
            "name": "Booking Test Hub",
            "category": "mall",
            "address_text": "Pune",
            "zone_id": "11111111-1111-4111-8111-111111111111",
            "latitude": 18.5204,
            "longitude": 73.8567,
        },
    )
    assert business.status_code == 201, business.text
    charger = await client.post(
        "/api/v1/chargers/",
        headers=owner_headers,
        json={
            "business_id": business.json()["id"],
            "name": "Lifecycle Charger",
            "charger_type": "public",
            "power_kw": 60,
            "status": "available",
            "latitude": 18.5204,
            "longitude": 73.8567,
        },
    )
    assert charger.status_code == 201, charger.text
    port = await client.post(
        f"/api/v1/chargers/{charger.json()['id']}/ports",
        headers=owner_headers,
        json={
            "connector_type_id": 1,
            "port_number": 1,
            "max_power_kw": 60,
            "is_active": True,
        },
    )
    assert port.status_code == 201, port.text

    local_start = (datetime.now(ZoneInfo("Asia/Kolkata")) + timedelta(days=1)).replace(
        hour=10, minute=0, second=0, microsecond=0
    )
    start = local_start.astimezone(UTC)
    window = await client.post(
        "/api/v1/availability/",
        headers=owner_headers,
        json={
            "charger_port_id": port.json()["id"],
            "day_of_week": local_start.weekday(),
            "start_local_time": "09:00:00",
            "end_local_time": "12:00:00",
            "is_unavailable": False,
        },
    )
    assert window.status_code == 201, window.text

    driver_headers = await _register_and_login(client, "driver")
    open_slots = await client.get(
        f"/api/v1/availability/port/{port.json()['id']}/slots",
        headers=driver_headers,
        params={"day": local_start.date().isoformat()},
    )
    assert open_slots.status_code == 200, open_slots.text
    assert any(
        datetime.fromisoformat(item["start_at"].replace("Z", "+00:00")) == start
        for item in open_slots.json()
    )
    held = await client.post(
        "/api/v1/bookings/",
        headers=driver_headers,
        json={
            "charger_port_id": port.json()["id"],
            "start_at": start.isoformat(),
            "end_at": (start + timedelta(hours=1)).isoformat(),
        },
    )
    assert held.status_code == 201, held.text
    assert held.json()["status"] == "held"
    assert held.json()["estimated_amount"] == 50.0

    with (
        patch.object(payments.settings, "RAZORPAY_KEY_ID", "rzp_test_configured"),
        patch.object(payments.settings, "RAZORPAY_KEY_SECRET", "configured_secret"),
        patch.object(payments.settings, "RAZORPAY_WEBHOOK_SECRET", "configured_webhook"),
        patch.object(
            payments.razorpay_client.order, "create", return_value={"id": "order_test_123"}
        ),
        patch.object(
            payments.razorpay_client.utility, "verify_payment_signature", return_value=None
        ),
    ):
        tampered_order = await client.post(
            "/api/v1/payments/create-order",
            headers=driver_headers,
            json={"booking_id": held.json()["id"], "amount": 0.01},
        )
        assert tampered_order.status_code == 422

        order = await client.post(
            "/api/v1/payments/create-order",
            headers=driver_headers,
            json={"booking_id": held.json()["id"]},
        )
        assert order.status_code == 201, order.text
        assert order.json()["amount"] == 50.0

        verified = await client.post(
            "/api/v1/payments/verify",
            headers=driver_headers,
            json={
                "booking_id": held.json()["id"],
                "provider_order_id": "order_test_123",
                "provider_payment_id": "pay_test_123",
                "provider_signature": "valid_signature",
            },
        )
        assert verified.status_code == 200, verified.text
        assert verified.json()["status"] == "completed"

    booking = await client.get(f"/api/v1/bookings/{held.json()['id']}", headers=driver_headers)
    assert booking.json()["status"] == "confirmed"

    with patch("app.services.session.datetime") as mock_dt:
        mock_dt.now.return_value = start
        mock_dt.UTC = UTC
        checked_in = await client.post(
            "/api/v1/sessions/check-in",
            headers=driver_headers,
            json={"booking_id": held.json()["id"]},
        )
        assert checked_in.status_code == 201, checked_in.text

    started = await client.post(
        f"/api/v1/sessions/{checked_in.json()['id']}/start",
        headers=driver_headers,
    )
    assert started.status_code == 200, started.text
    completed = await client.post(
        f"/api/v1/sessions/{checked_in.json()['id']}/complete",
        headers=driver_headers,
        json={"energy_kwh": 12.5},
    )
    assert completed.status_code == 200, completed.text
    assert completed.json()["status"] == "completed"

    review = await client.post(
        f"/api/v1/sessions/{checked_in.json()['id']}/rating",
        headers=driver_headers,
        json={
            "session_id": checked_in.json()["id"],
            "rating": 2,
            "comment": "Connector was loose",
            "issue_flags": ["Connector issue"],
        },
    )
    assert review.status_code == 201, review.text
    assert review.json()["issue_flags"] == ["Connector issue"]
