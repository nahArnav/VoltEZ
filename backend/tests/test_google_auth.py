from unittest.mock import Mock

import pytest
from fastapi import HTTPException

from app.core.config import settings
from app.services import auth as auth_module
from app.services.auth import auth_service


@pytest.mark.asyncio
async def test_google_id_token_is_verified_for_web_client_audience(monkeypatch):
    verifier = Mock(
        return_value={
            "sub": "google-account-123",
            "email": "Driver@Example.com",
            "email_verified": True,
            "name": "VoltEZ Driver",
        }
    )
    monkeypatch.setattr(auth_module.google_id_token, "verify_oauth2_token", verifier)

    identity = await auth_service.verify_google_id_token("signed-google-id-token")

    assert identity.subject == "google-account-123"
    assert identity.email == "driver@example.com"
    assert identity.name == "VoltEZ Driver"
    assert verifier.call_args.args[2] == settings.GOOGLE_WEB_CLIENT_ID


@pytest.mark.asyncio
async def test_invalid_google_id_token_is_rejected(monkeypatch):
    def reject_token(*_args, **_kwargs):
        raise ValueError("bad signature")

    monkeypatch.setattr(
        auth_module.google_id_token,
        "verify_oauth2_token",
        reject_token,
    )

    with pytest.raises(HTTPException) as error:
        await auth_service.verify_google_id_token("forged-token")

    assert error.value.status_code == 401
    assert error.value.detail == "Invalid Google ID token."
