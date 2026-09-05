from uuid import uuid4

import pytest

from app.services.auth import GoogleIdentity, auth_service

pytestmark = pytest.mark.integration


# We mark this test as 'asyncio' because our FastAPI app is asynchronous
@pytest.mark.asyncio
async def test_register_new_user(client):
    """
    Test that a new user can successfully register, and their data is saved.
    """
    # 1. ARRANGE: The data the "mobile app" is sending
    email = f"driver-{uuid4()}@example.com"
    payload = {
        "email": email,
        "password": "SecurePassword123!",
        "name": "Test Driver",  # <--- Changed from full_name to name
        "role": "driver",
    }

    # 2. ACT: Send the POST request to the API
    # (Adjust the "/api/v1/auth/register" URL if your route is slightly different)
    response = await client.post("/api/v1/auth/register", json=payload)

    # 3. ASSERT: Verify the API responded exactly how we expect
    assert response.status_code == 201, response.text  # <--- We added ", response.text"
    data = response.json()

    assert data["email"] == email
    assert "id" in data  # Proves the database actually generated a UUID/ID
    assert "password" not in data  # SECURITY CHECK: API should NEVER return the password!


@pytest.mark.asyncio
async def test_login_user(client):
    """
    Test that an existing user can log in and receive a valid JWT token.
    """
    # 1. ARRANGE: Register a user first so they exist in the test database
    password = "SecurePassword123!"
    email = f"login-{uuid4()}@example.com"
    register_payload = {
        "email": email,
        "password": password,
        "name": "Login Tester",
        "role": "driver",
    }
    await client.post("/api/v1/auth/register", json=register_payload)

    # 2. ACT: Attempt to log in with those exact credentials
    # Login endpoint uses OAuth2PasswordRequestForm, which expects form data with "username" field
    response = await client.post(
        "/api/v1/auth/login", data={"username": email, "password": password}
    )

    # 3. ASSERT: We expect a 200 OK and a JWT token in the response
    assert response.status_code == 200, response.text

    data = response.json()
    assert "access_token" in data  # Proves the system gave us a JWT
    assert data["token_type"].lower() == "bearer"


@pytest.mark.asyncio
async def test_google_login_creates_session_and_returns_current_user(client, monkeypatch):
    email = f"google-{uuid4()}@example.com"

    async def verified_identity(_id_token: str) -> GoogleIdentity:
        return GoogleIdentity(
            subject="google-account-123",
            email=email,
            name="Google Driver",
        )

    monkeypatch.setattr(auth_service, "verify_google_id_token", verified_identity)

    response = await client.post(
        "/api/v1/auth/google",
        json={"id_token": "signed-google-id-token", "role": "driver"},
    )

    assert response.status_code == 200, response.text
    tokens = response.json()
    assert tokens["access_token"]
    assert tokens["refresh_token"]

    me = await client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )
    assert me.status_code == 200, me.text
    assert me.json()["email"] == email
    assert me.json()["name"] == "Google Driver"
    assert me.json()["role"] == "driver"
