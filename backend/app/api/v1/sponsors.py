import httpx
from fastapi import APIRouter, Query
from pydantic import BaseModel, Field

from app.core.config import settings

router = APIRouter(prefix="/sponsors", tags=["Sponsor Integrations"])


# ─────────────────────────────────────────────────────────────────────────────
# 1. Tavily Search Integration (Live Electricity Tariffs & EV News)
# ─────────────────────────────────────────────────────────────────────────────
class TariffSearchResponse(BaseModel):
    query: str
    state_or_discom: str
    results: list[dict]
    source: str


@router.get("/tariffs", response_model=TariffSearchResponse)
async def get_live_discom_tariffs(
    state: str = Query(default="Maharashtra", description="Indian State or DISCOM name"),
):
    """Fetch live EV charging electricity tariffs using Tavily search."""
    query = f"{state} EV charging station electricity tariff per kWh DISCOM regulatory order"
    tavily_key = settings.TAVILY_API_KEY.strip()

    if tavily_key:
        try:
            async with httpx.AsyncClient(timeout=6.0) as client:
                resp = await client.post(
                    "https://api.tavily.com/search",
                    json={
                        "api_key": tavily_key,
                        "query": query,
                        "search_depth": "basic",
                        "max_results": 4,
                    },
                )
                if resp.status_code == 200:
                    data = resp.json()
                    return TariffSearchResponse(
                        query=query,
                        state_or_discom=state,
                        results=data.get("results", []),
                        source="Tavily Live Search",
                    )
        except Exception:
            pass

    # Never fabricate tariff values when the live provider is unavailable.
    # Consumers can distinguish this empty response from real search results
    # and configure TAVILY_API_KEY without showing stale pricing to drivers.
    return TariffSearchResponse(
        query=query,
        state_or_discom=state,
        results=[],
        source="Tavily not configured",
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


@router.post("/copilot", response_model=CopilotResponse)
async def ask_gemini_copilot(req: CopilotRequest):
    """Provide AI EV assistance or Host pricing advisory using Google Gemini."""
    gemini_key = settings.GEMINI_API_KEY.strip()
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

    if gemini_key:
        headers = {"x-goog-api-key": gemini_key, "Content-Type": "application/json"}
        for model_name in ["models/gemini-2.5-flash", "models/gemini-2.0-flash", "models/gemini-flash-latest", "models/gemini-pro-latest"]:
            try:
                async with httpx.AsyncClient(timeout=6.0) as client:
                    resp = await client.post(
                        f"https://generativelanguage.googleapis.com/v1beta/{model_name}:generateContent?key={gemini_key}",
                        headers=headers,
                        json={"contents": [{"parts": [{"text": user_prompt}]}]},
                    )
                    if resp.status_code == 200:
                        candidates = resp.json().get("candidates", [])
                        if candidates:
                            text = candidates[0]["content"]["parts"][0]["text"].strip()
                            return CopilotResponse(
                                advice=text,
                                model=model_name,
                                source="Google Gemini",
                            )
            except Exception:
                continue

    # No made-up charge times, tariffs or connector advice. The client can
    # clearly distinguish an unavailable sponsor service from live Gemini
    # output and continue using VoltEZ's deterministic recommendation engine.
    return CopilotResponse(
        advice=(
            "Live Gemini advice is unavailable right now. Configure "
            "GEMINI_API_KEY on the backend or try again later."
        ),
        model="unavailable",
        source="Gemini not configured",
    )



# ─────────────────────────────────────────────────────────────────────────────
# 3. StartupEd & Swytchcode Sponsor Ecosystem Hub
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/ecosystem")
async def get_sponsor_ecosystem_status():
    """Return live status of integrated sponsors and developer tools."""
    return {
        "sponsors": {
            "google_for_developers": {
                "features": ["Places API (New) Autocomplete", "Place Details", "Routes API"],
                "active": bool(settings.GOOGLE_MAPS_API_KEY),
            },
            "google_gemini": {
                "features": ["AI Driver Copilot", "Host Revenue Advisor"],
                "active": bool(settings.GEMINI_API_KEY),
            },
            "tavily": {
                "features": ["Live DISCOM Electricity Tariff Search", "State EV Policy Radar"],
                "active": bool(settings.TAVILY_API_KEY),
            },
            "lyzr": {
                "features": ["Autonomous EV Agent Framework"],
                "active": bool(settings.LYZR_API_KEY),
            },
            "startuped": {
                "features": ["EV Host Entrepreneurship Program", "Partner Certification"],
                "active": bool(settings.STARTUPED_API_KEY),
                "key_preview": f"{settings.STARTUPED_API_KEY[:8]}..." if settings.STARTUPED_API_KEY else None,
            },
            "swytchcode": {
                "features": ["Verified Charging Session Audit", "Smart Meter Cryptographic Proof"],
                "active": bool(settings.SWYTCHCODE_API_KEY),
                "key_preview": f"{settings.SWYTCHCODE_API_KEY[:8]}..." if settings.SWYTCHCODE_API_KEY else None,
            },
            "stripe": {
                "features": ["Hosted Stripe Checkout", "Card & Digital Wallet Webhooks"],
                "active": settings.stripe_is_configured,
            },
        }
    }
