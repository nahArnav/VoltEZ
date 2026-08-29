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

    # Location search. When present, the backend uses Google's Places
    # autocomplete + details APIs for high-quality, coordinate-backed
    # suggestions. Without a key we fall back to the no-key Nominatim adapter.
    GOOGLE_MAPS_API_KEY: str = ""

    # Razorpay Integration
    RAZORPAY_KEY_ID: str = "rzp_test_placeholder"
    RAZORPAY_KEY_SECRET: str = "rzp_secret_placeholder"
    RAZORPAY_WEBHOOK_SECRET: str = "rzp_webhook_secret"
    # Stripe Checkout is the preferred gateway when a real secret is present.
    # Razorpay remains a safe fallback for existing development accounts.
    STRIPE_SECRET_KEY: str = "sk_test_placeholder"
    STRIPE_PUBLISHABLE_KEY: str = "pk_test_placeholder"
    STRIPE_WEBHOOK_SECRET: str = "whsec_test_placeholder"
    STRIPE_SUCCESS_URL: str = "https://example.invalid/payment/success"
    STRIPE_CANCEL_URL: str = "https://example.invalid/payment/cancel"
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

    @property
    def stripe_is_configured(self) -> bool:
        return self.STRIPE_SECRET_KEY not in {"", "sk_test_placeholder", "sk_live_placeholder"}

    @property
    def active_payment_provider(self) -> str:
        """Select Stripe automatically, otherwise retain Razorpay fallback."""
        return "stripe" if self.stripe_is_configured else "razorpay"

    @model_validator(mode="after")
    def validate_production_settings(self):
        """Fail closed instead of deploying with development security values."""
        if self.ENVIRONMENT.lower() != "production":
            return self
        if len(self.SECRET_KEY) < 32:
            raise ValueError("SECRET_KEY must contain at least 32 characters in production")
        if self.CORS_ORIGINS.strip() == "*":
            raise ValueError("CORS_ORIGINS must list explicit origins in production")
        if not (self.stripe_is_configured or self.razorpay_is_configured):
            raise ValueError("Stripe or Razorpay credentials must be configured in production")
        if self.stripe_is_configured and (
            "example.invalid" in self.STRIPE_SUCCESS_URL
            or "example.invalid" in self.STRIPE_CANCEL_URL
            or self.STRIPE_WEBHOOK_SECRET == "whsec_test_placeholder"
        ):
            raise ValueError("Stripe success/cancel URLs must be set in production")
        return self

    # This tells Pydantic to read from .env or backend/.env file
    model_config = SettingsConfigDict(
        env_file=(".env", "backend/.env"), env_file_encoding="utf-8", extra="ignore"
    )


# Create a global instance of the settings to use throughout the app
settings = Settings()  # type: ignore
