import pytest
from pydantic import ValidationError

from app.core.config import Settings


def test_production_rejects_development_signing_secret() -> None:
    with pytest.raises(ValidationError, match="SECRET_KEY"):
        Settings(
            ENVIRONMENT="production",
            DATABASE_URL="postgresql://localhost/voltez",
            SECRET_KEY="local-development-secret-change-before-deploying",
        )


def test_production_accepts_strong_signing_secret() -> None:
    config = Settings(
        ENVIRONMENT="production",
        DATABASE_URL="postgresql://localhost/voltez",
        SECRET_KEY="a-production-only-signing-secret-with-ample-entropy",
    )

    assert config.ENVIRONMENT == "production"
