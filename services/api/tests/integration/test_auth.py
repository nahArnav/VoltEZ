import pytest

# We mark this test as 'asyncio' because our FastAPI app is asynchronous
@pytest.mark.asyncio
async def test_register_new_user(client):
    """
    Test that a new user can successfully register, and their data is saved.
    """
   # 1. ARRANGE: The data the "mobile app" is sending
    payload = {
        "email": "testdriver1@voltez.com",
        "password": "SecurePassword123!",
        "name": "Test Driver",  # <--- Changed from full_name to name
        "role": "DRIVER"        # <--- Changed from driver to DRIVER
    }

    # 2. ACT: Send the POST request to the API
    # (Adjust the "/api/v1/auth/register" URL if your route is slightly different)
    response = await client.post("/api/v1/auth/register", json=payload)

    # 3. ASSERT: Verify the API responded exactly how we expect
    assert response.status_code == 201, response.text  # <--- We added ", response.text"
    data = response.json()

    assert data["email"] == "testdriver1@voltez.com"
    assert "id" in data  # Proves the database actually generated a UUID/ID
    assert "password" not in data  # SECURITY CHECK: API should NEVER return the password!