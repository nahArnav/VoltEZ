from fastapi import APIRouter, Query, Request
from pydantic import BaseModel, Field

from app.core.config import settings
from app.integrations.providers import generate_gemini_text, search_tavily

router = APIRouter(prefix="/sponsors", tags=["Sponsor Integrations"])


# ─────────────────────────────────────────────────────────────────────────────
# 1. Tavily Search Integration (Live Electricity Tariffs & EV News)
# ─────────────────────────────────────────────────────────────────────────────
class TariffSearchResponse(BaseModel):
    query: str
    state_or_discom: str
    results: list[dict]
    source: str
    provider_status: str
    error_code: str | None = None


@router.get("/tariffs", response_model=TariffSearchResponse)
async def get_live_discom_tariffs(
    request: Request,
    state: str = Query(default="Maharashtra", description="Indian State or DISCOM name"),
):
    """Fetch live EV charging electricity tariffs using Tavily search."""
    query = f"{state} EV charging station electricity tariff per kWh DISCOM regulatory order"
    result = await search_tavily(
        query,
        max_results=4,
        client=getattr(request.app.state, "http_client", None),
    )
    if result.status == "ok":
        return TariffSearchResponse(
            query=query,
            state_or_discom=state,
            results=result.results,
            source="Tavily Live Search",
            provider_status="ok",
        )

    # Never fabricate tariff values when the live provider is unavailable.
    # Consumers can distinguish this empty response from real search results
    # and configure TAVILY_API_KEY without showing stale pricing to drivers.
    return TariffSearchResponse(
        query=query,
        state_or_discom=state,
        results=[],
        source=(
            "Tavily not configured" if result.status == "not_configured" else "Tavily unavailable"
        ),
        provider_status=result.status,
        error_code=result.error_code,
    )


# ─────────────────────────────────────────────────────────────────────────────
# 2. Google Gemini Integration (AI Charging Copilot & Host Advisor)
# ─────────────────────────────────────────────────────────────────────────────
class CopilotRequest(BaseModel):
    prompt: str = Field(..., min_length=2, max_length=1000)
    context: str = "driver"  # "driver" or "host"
    vehicle_model: str | None = None
    connector_type: str | None = None
    battery_level: int | None = Field(default=None, ge=0, le=100)


class CopilotResponse(BaseModel):
    advice: str
    model: str
    source: str
    provider_status: str
    error_code: str | None = None


@router.post("/copilot", response_model=CopilotResponse)
async def ask_gemini_copilot(req: CopilotRequest, request: Request):
    """Provide AI EV assistance or Host pricing advisory using Google Gemini."""
    system_ctx = (
        "You are VoltEZ EV Copilot, an AI assistant for electric vehicle drivers and private charger hosts in India. "
        "Provide concise, actionable advice in 2-3 sentences max."
    )
    user_prompt = (
        f"{system_ctx}\nContext: {req.context}\n"
        f"Vehicle: {req.vehicle_model or 'Not provided'}\n"
        f"Connector: {req.connector_type or 'Not provided'}\n"
        f"Battery: {req.battery_level if req.battery_level is not None else 'Not provided'}%\n"
        f"Question: {req.prompt}"
    )

    result = await generate_gemini_text(
        user_prompt,
        max_output_tokens=300,
        temperature=0.2,
        client=getattr(request.app.state, "http_client", None),
    )
    if result.text:
        return CopilotResponse(
            advice=result.text,
            model=result.model or "gemini",
            source="Google Gemini",
            provider_status="ok",
        )

    # No made-up charge times, tariffs or connector advice. The client can
    # clearly distinguish an unavailable sponsor service from live Gemini
    # output and continue using VoltEZ's deterministic recommendation engine.
    return CopilotResponse(
        advice=(
            "Live Gemini advice is unavailable right now. "
            + (
                "Configure GEMINI_API_KEY on the backend."
                if result.status == "not_configured"
                else "The configured provider credentials or quota need attention."
            )
        ),
        model="unavailable",
        source=(
            "Gemini not configured" if result.status == "not_configured" else "Gemini unavailable"
        ),
        provider_status=result.status,
        error_code=result.error_code,
    )


# ─────────────────────────────────────────────────────────────────────────────
# 3. StartupEd & Swytchcode Sponsor Ecosystem Hub
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/ecosystem")
async def get_sponsor_ecosystem_status():
    """Return configuration status without exposing or pretending to verify keys."""

    def provider_status(*, configured: bool, implemented: bool) -> dict[str, bool]:
        return {
            "configured": configured,
            "implemented": implemented,
            "active": configured and implemented,
        }

    return {
        "status_note": (
            "active means configured and implemented; call the feature endpoint "
            "to verify the provider accepts its credentials"
        ),
        "sponsors": {
            "google_for_developers": {
                "features": ["Places API (New) Autocomplete", "Place Details", "Routes API"],
                **provider_status(
                    configured=bool(settings.GOOGLE_MAPS_API_KEY.strip()),
                    implemented=True,
                ),
            },
            "google_gemini": {
                "features": ["AI Driver Copilot", "Host Revenue Advisor"],
                **provider_status(
                    configured=bool(settings.GEMINI_API_KEY.strip()),
                    implemented=True,
                ),
            },
            "tavily": {
                "features": ["Live DISCOM Electricity Tariff Search", "State EV Policy Radar"],
                **provider_status(
                    configured=bool(settings.TAVILY_API_KEY.strip()),
                    implemented=True,
                ),
            },
            "lyzr": {
                "features": ["Autonomous EV Agent Framework"],
                **provider_status(
                    configured=bool(settings.LYZR_API_KEY.strip()),
                    implemented=False,
                ),
            },
            "startuped": {
                "features": ["EV Host Entrepreneurship Program", "Partner Certification"],
                **provider_status(
                    configured=bool(settings.STARTUPED_API_KEY.strip()),
                    implemented=False,
                ),
            },
            "swytchcode": {
                "features": ["Verified Charging Session Audit", "Smart Meter Cryptographic Proof"],
                **provider_status(
                    configured=bool(settings.SWYTCHCODE_API_KEY.strip()),
                    implemented=False,
                ),
            },
            "stripe": {
                "features": ["Hosted Stripe Checkout", "Card & Digital Wallet Webhooks"],
                **provider_status(
                    configured=settings.stripe_is_configured,
                    implemented=True,
                ),
            },
        },
    }
