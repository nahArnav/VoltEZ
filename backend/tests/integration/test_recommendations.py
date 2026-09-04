from uuid import uuid4

import pytest

pytestmark = pytest.mark.integration


@pytest.mark.asyncio
async def test_recommendations_endpoint(client):
    """
    Test the recommendation engine returns valid results and scores.
    """
    # 1. Setup Driver and Vehicle
    password = "SecurePassword123!"
    register_payload = {
        "email": f"recommendation-{uuid4()}@example.com",
        "password": password,
        "name": "Rec Driver",
        "role": "driver",
    }
    await client.post("/api/v1/auth/register", json=register_payload)
    login_response = await client.post(
        "/api/v1/auth/login", data={"username": register_payload["email"], "password": password}
    )
    token = login_response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    vehicle_payload = {
        "make": "MG",
        "model": "ZS EV",
        "vehicle_class": "compact_suv",
        "battery_kwh": 50.3,
        "connector_type_ids": [1],
        "max_ac_kw": 7.4,
        "max_dc_kw": 50.0,
        "estimated_range_km": 461.0,
    }
    veh_resp = await client.post("/api/v1/vehicles/", json=vehicle_payload, headers=headers)
    assert veh_resp.status_code == 201
    vehicle_id = veh_resp.json()["id"]

    # 2. Ask for recommendations
    # If the DB is empty (no chargers), this will return an empty list, which is valid.
    rec_payload = {
        "latitude": 18.5204,
        "longitude": 73.8567,
        "destination_latitude": 18.4000,
        "destination_longitude": 73.8500,
        "radius_meters": 10000.0,
        "vehicle_id": vehicle_id,
        "current_soc": 0.2,
        "target_soc": 0.8,
        "reserve_soc": 0.1,
        "route_distance_km": 14.0,
        "route_duration_minutes": 28,
        "preferences": {"mode": "balanced"},
    }

    rec_response = await client.post("/api/v1/recommendations/", json=rec_payload, headers=headers)
    assert rec_response.status_code == 200, rec_response.text
    data = rec_response.json()
    assert "recommendations" in data
    assert data["route_plan"]["algorithm"] == "astar"
    assert data["route_plan"]["mode"] == "balanced"
    assert data["route_plan"]["reachable"] is True

    # We just ensure the endpoint doesn't crash and returns valid schema
    assert isinstance(data["recommendations"], list)
