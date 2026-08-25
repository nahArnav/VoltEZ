from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional


class Settings(BaseSettings):
    PROJECT_NAME: str
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"

    # Required production secrets
    SECRET_KEY: str
    DATABASE_URL: str

    # ML Integrations
    ML_MODEL_API_URL: str = "http://localhost:8001"

    # Razorpay Integration
    RAZORPAY_KEY_ID: str = "rzp_test_placeholder"
    RAZORPAY_KEY_SECRET: str = "rzp_secret_placeholder"
    RAZORPAY_WEBHOOK_SECRET: str = "rzp_webhook_secret"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # JWT configuration
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # CORS - comma-separated origins, or ["*"] for dev
    CORS_ORIGINS: str = "*"

    @property
    def cors_origins_list(self) -> list[str]:
        """Parse CORS_ORIGINS into a list."""
        if self.CORS_ORIGINS == "*":
            return ["*"]
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",")]

    # This tells Pydantic to read from .env or backend/.env file
    model_config = SettingsConfigDict(env_file=(".env", "backend/.env"), env_file_encoding="utf-8", extra="ignore")


# Create a global instance of the settings to use throughout the app
settings = Settings()  # type: ignore