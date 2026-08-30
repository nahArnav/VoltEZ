from uuid import uuid4

import pytest

pytestmark = pytest.mark.integration


@pytest.mark.asyncio
async def test_crud_vehicle(client):
    """
    Test the full CRUD lifecycle for vehicles and connector validation.
    """
    # 1. Register and login to get token
    password = "SecurePassword123!"
    register_payload = {
        "email": f"vehicle-{uuid4()}@example.com",
        "password": password,
        "name": "Vehicle Driver",
        "role": "driver",
    }
    await client.post("/api/v1/auth/register", json=register_payload)

    login_response = await client.post(
        "/api/v1/auth/login", data={"username": register_payload["email"], "password": password}
    )
    token = login_response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. CREATE a vehicle
    vehicle_payload = {
        "make": "Tata",
        "model": "Nexon EV",
        "vehicle_class": "compact_suv",
        "battery_kwh": 30.2,
        "connector_type_ids": [1],
        "max_ac_kw": 7.2,
        "max_dc_kw": 25.0,
        "estimated_range_km": 312.0,
    }
    create_response = await client.post("/api/v1/vehicles/", json=vehicle_payload, headers=headers)
    assert create_response.status_code == 201, create_response.text
    vehicle_data = create_response.json()
    assert vehicle_data["make"] == "Tata"
    assert vehicle_data["connector_type_ids"] == [1]
    vehicle_id = vehicle_data["id"]

    # 3. GET the vehicle
    get_response = await client.get(f"/api/v1/vehicles/{vehicle_id}", headers=headers)
    assert get_response.status_code == 200, get_response.text
    assert get_response.json()["id"] == vehicle_id

    # 4. UPDATE the vehicle (e.g. change range)
    update_response = await client.patch(
        f"/api/v1/vehicles/{vehicle_id}", json={"estimated_range_km": 250.0}, headers=headers
    )
    assert update_response.status_code == 200, update_response.text
    assert update_response.json()["estimated_range_km"] == 250.0

    # 5. LIST vehicles
    list_response = await client.get("/api/v1/vehicles/", headers=headers)
    assert list_response.status_code == 200, list_response.text
    assert len(list_response.json()) == 1

    # 6. DELETE the vehicle
    del_response = await client.delete(f"/api/v1/vehicles/{vehicle_id}", headers=headers)
    assert del_response.status_code == 204

    # Verify it's deleted
    get_del_response = await client.get(f"/api/v1/vehicles/{vehicle_id}", headers=headers)
    assert get_del_response.status_code == 404
