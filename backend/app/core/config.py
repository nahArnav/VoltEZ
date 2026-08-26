from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str
    ENVIRONMENT: str = "development"
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
    BOOKING_HOLD_FEE_INR: float = 50.0
    DEFAULT_PRICE_PER_KWH_INR: float = 15.0

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

    @property
    def razorpay_is_configured(self) -> bool:
        """Reject payment attempts when template credentials are still active."""
        placeholders = {"rzp_test_placeholder", "rzp_secret_placeholder", "rzp_webhook_secret"}
        return not {
            self.RAZORPAY_KEY_ID,
            self.RAZORPAY_KEY_SECRET,
            self.RAZORPAY_WEBHOOK_SECRET,
        }.intersection(placeholders)

    @model_validator(mode="after")
    def validate_production_settings(self):
        """Fail closed instead of deploying with development security values."""
        if self.ENVIRONMENT.lower() != "production":
            return self
        if len(self.SECRET_KEY) < 32:
            raise ValueError("SECRET_KEY must contain at least 32 characters in production")
        if self.CORS_ORIGINS.strip() == "*":
            raise ValueError("CORS_ORIGINS must list explicit origins in production")
        if not self.razorpay_is_configured:
            raise ValueError("Razorpay credentials must be configured in production")
        return self

    # This tells Pydantic to read from .env or backend/.env file
    model_config = SettingsConfigDict(env_file=(".env", "backend/.env"), env_file_encoding="utf-8", extra="ignore")


# Create a global instance of the settings to use throughout the app
settings = Settings()  # type: ignore
