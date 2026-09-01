from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "VoltEZ API"
    ENVIRONMENT: str = "development"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"

    # Production secrets (defaults for development convenience)
    SECRET_KEY: str = "local-development-secret-change-before-deploying"
    DATABASE_URL: str

    # ML Integrations
    ML_MODEL_API_URL: str = "http://localhost:8001"

    # Location search. When present, the backend uses Google Places API (New)
    # and Routes API for high-quality coordinate-backed suggestions & live ETAs.
    GOOGLE_MAPS_API_KEY: str = ""

    # Sponsor Integrations
    GEMINI_API_KEY: str = ""
    TAVILY_API_KEY: str = ""
    LYZR_API_KEY: str = ""
    LYZR_AGENT_ID: str = ""
    STARTUPED_API_KEY: str = ""
    SWYTCHCODE_API_KEY: str = ""
    N8N_BASE_URL: str = ""
    N8N_WEBHOOK_URL: str = ""
    N8N_API_KEY: str = ""
    N8N_WEBHOOK_SECRET: str = ""

    # Firebase Cloud Messaging
    FIREBASE_PROJECT_ID: str = ""
    FIREBASE_CLIENT_EMAIL: str = ""
    FIREBASE_PRIVATE_KEY: str = ""
    FCM_VAPID_KEY: str = ""


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
    CASH_OTP_TTL_MINUTES: int = 1440
    CASH_OTP_MAX_ATTEMPTS: int = 5

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
        """Warn on insecure values in production instead of hard-failing."""
        if self.ENVIRONMENT.lower() != "production":
            return self
        if len(self.SECRET_KEY) < 32:
            import warnings
            warnings.warn("SECRET_KEY should contain at least 32 characters in production", stacklevel=2)
        # Cash pay-at-charger is a valid production mode. Gateway credentials
        # are required only when card/UPI checkout is enabled, not to boot the
        # application or accept cash reservations.
        return self

    # This tells Pydantic to read from .env or backend/.env file
    model_config = SettingsConfigDict(
        env_file=(".env", "backend/.env"), env_file_encoding="utf-8", extra="ignore"
    )


# Create a global instance of the settings to use throughout the app
settings = Settings()  # type: ignore
