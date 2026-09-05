"""HTTP clients for external AI and search providers.

The public API routes deliberately expose only coarse status/error codes. Full
provider responses stay in Render logs and API keys are never logged.
"""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass
from typing import Any

import httpx

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger("provider_integrations")

_GEMINI_GENERATE_URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
)
_TAVILY_SEARCH_URL = "https://api.tavily.com/search"


@asynccontextmanager
async def _provider_client(
    client: httpx.AsyncClient | None,
    *,
    timeout: float,
) -> AsyncIterator[httpx.AsyncClient]:
    """Reuse the app-scoped HTTP pool, with a test/local fallback."""
    if client is not None:
        yield client
        return
    async with httpx.AsyncClient(timeout=timeout) as owned_client:
        yield owned_client


def normalize_secret(value: str) -> str:
    """Trim whitespace and accidental matching quotes from dashboard values."""
    cleaned = value.strip()
    if len(cleaned) >= 2 and cleaned[0] == cleaned[-1] and cleaned[0] in {"'", '"'}:
        cleaned = cleaned[1:-1].strip()
    return cleaned


def _error_code(response: httpx.Response) -> str:
    code = f"http_{response.status_code}"
    try:
        payload = response.json()
        error = payload.get("error", {}) if isinstance(payload, dict) else {}
        provider_code = error.get("status") if isinstance(error, dict) else None
        if isinstance(provider_code, str) and provider_code:
            safe_code = "".join(
                char.lower() if char.isalnum() else "_" for char in provider_code
            ).strip("_")
            if safe_code:
                code = f"{code}_{safe_code[:60]}"
    except (TypeError, ValueError):
        pass
    return code


def _provider_status(status_code: int) -> str:
    if status_code in {401, 403}:
        return "credentials_rejected"
    if status_code == 429:
        return "rate_limited"
    return "provider_error"


@dataclass(frozen=True)
class GeminiResult:
    text: str | None
    model: str | None
    status: str
    error_code: str | None = None


@dataclass(frozen=True)
class TavilyResult:
    results: list[dict[str, Any]]
    status: str
    error_code: str | None = None


def _gemini_models() -> list[str]:
    configured = settings.GEMINI_MODEL.strip().removeprefix("models/")
    ordered = [
        configured,
        "gemini-3.7-flash",
        "gemini-3.6-flash",
        "gemini-2.5-flash",
    ]
    return list(dict.fromkeys(model for model in ordered if model))


async def generate_gemini_text(
    prompt: str,
    *,
    max_output_tokens: int = 500,
    temperature: float = 0.2,
    client: httpx.AsyncClient | None = None,
) -> GeminiResult:
    key = normalize_secret(settings.GEMINI_API_KEY)
    if not key:
        return GeminiResult(text=None, model=None, status="not_configured")

    last_status = "provider_error"
    last_error = "no_usable_response"
    headers = {
        "x-goog-api-key": key,
        "Content-Type": "application/json",
    }
    body = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": temperature,
            "maxOutputTokens": max_output_tokens,
        },
    }

    try:
        async with _provider_client(client, timeout=12.0) as active_client:
            for model in _gemini_models():
                try:
                    response = await active_client.post(
                        _GEMINI_GENERATE_URL.format(model=model),
                        headers=headers,
                        json=body,
                        timeout=12.0,
                    )
                except httpx.HTTPError as exc:
                    last_status = "network_error"
                    last_error = type(exc).__name__.lower()
                    logger.warning(
                        "Gemini request failed model=%s error=%s",
                        model,
                        type(exc).__name__,
                    )
                    continue

                if response.status_code != 200:
                    last_status = _provider_status(response.status_code)
                    last_error = _error_code(response)
                    logger.warning(
                        "Gemini rejected request model=%s status=%d error=%s",
                        model,
                        response.status_code,
                        last_error,
                    )
                    if response.status_code in {401, 403, 429}:
                        break
                    continue

                try:
                    candidates = response.json().get("candidates", [])
                    parts = candidates[0].get("content", {}).get("parts", [])
                    text = parts[0].get("text", "").strip() if parts else ""
                except (AttributeError, IndexError, TypeError, ValueError):
                    text = ""
                if text:
                    return GeminiResult(text=text, model=model, status="ok")

                last_status = "empty_response"
                last_error = "no_text_candidate"
                logger.warning("Gemini returned no text candidate model=%s", model)
    except httpx.HTTPError as exc:
        last_status = "network_error"
        last_error = type(exc).__name__.lower()
        logger.warning("Gemini client failed error=%s", type(exc).__name__)

    return GeminiResult(
        text=None,
        model=None,
        status=last_status,
        error_code=last_error,
    )


async def search_tavily(
    query: str,
    *,
    max_results: int = 4,
    client: httpx.AsyncClient | None = None,
) -> TavilyResult:
    key = normalize_secret(settings.TAVILY_API_KEY)
    if not key:
        return TavilyResult(results=[], status="not_configured")

    try:
        async with _provider_client(client, timeout=10.0) as active_client:
            response = await active_client.post(
                _TAVILY_SEARCH_URL,
                headers={
                    "Authorization": f"Bearer {key}",
                    "Content-Type": "application/json",
                },
                json={
                    "query": query,
                    "search_depth": "basic",
                    "max_results": max_results,
                },
                timeout=10.0,
            )
    except httpx.HTTPError as exc:
        logger.warning("Tavily request failed error=%s", type(exc).__name__)
        return TavilyResult(
            results=[],
            status="network_error",
            error_code=type(exc).__name__.lower(),
        )

    if response.status_code != 200:
        error_code = _error_code(response)
        logger.warning(
            "Tavily rejected request status=%d error=%s",
            response.status_code,
            error_code,
        )
        return TavilyResult(
            results=[],
            status=_provider_status(response.status_code),
            error_code=error_code,
        )

    try:
        results = response.json().get("results", [])
    except (AttributeError, TypeError, ValueError):
        results = []
    if not isinstance(results, list):
        results = []
    return TavilyResult(results=results, status="ok")
