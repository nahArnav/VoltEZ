from collections.abc import Iterable
from typing import Any

import httpx
import pytest

from app.core.config import settings
from app.integrations import providers


class FakeAsyncClient:
    def __init__(self, responses: Iterable[httpx.Response]):
        self.responses = iter(responses)
        self.calls: list[dict[str, Any]] = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, traceback):
        return False

    async def post(self, url: str, **kwargs) -> httpx.Response:
        self.calls.append({"url": url, **kwargs})
        return next(self.responses)


def _response(status_code: int, payload: dict[str, Any]) -> httpx.Response:
    return httpx.Response(
        status_code,
        json=payload,
        request=httpx.Request("POST", "https://provider.invalid"),
    )


def test_normalize_secret_removes_accidental_dashboard_quotes() -> None:
    assert providers.normalize_secret('  "secret-value"  ') == "secret-value"
    assert providers.normalize_secret("'secret-value'") == "secret-value"


@pytest.mark.asyncio
async def test_gemini_uses_header_auth_and_current_model(monkeypatch) -> None:
    fake = FakeAsyncClient(
        [_response(200, {"candidates": [{"content": {"parts": [{"text": "works"}]}}]})]
    )
    monkeypatch.setattr(settings, "GEMINI_API_KEY", '"new-key"')
    monkeypatch.setattr(settings, "GEMINI_MODEL", "gemini-3.7-flash")
    monkeypatch.setattr(providers.httpx, "AsyncClient", lambda **_: fake)

    result = await providers.generate_gemini_text("hello")

    assert result.status == "ok"
    assert result.text == "works"
    assert result.model == "gemini-3.7-flash"
    assert fake.calls[0]["headers"]["x-goog-api-key"] == "new-key"
    assert "?key=" not in fake.calls[0]["url"]
    assert fake.calls[0]["url"].endswith("models/gemini-3.7-flash:generateContent")


@pytest.mark.asyncio
async def test_tavily_uses_bearer_auth_not_body_key(monkeypatch) -> None:
    fake = FakeAsyncClient([_response(200, {"results": [{"title": "tariff"}]})])
    monkeypatch.setattr(settings, "TAVILY_API_KEY", "tvly-test")
    monkeypatch.setattr(providers.httpx, "AsyncClient", lambda **_: fake)

    result = await providers.search_tavily("Maharashtra EV tariff")

    assert result.status == "ok"
    assert result.results == [{"title": "tariff"}]
    assert fake.calls[0]["headers"]["Authorization"] == "Bearer tvly-test"
    assert "api_key" not in fake.calls[0]["json"]


@pytest.mark.asyncio
async def test_provider_rejection_returns_safe_diagnostics(monkeypatch) -> None:
    fake = FakeAsyncClient(
        [
            _response(
                401,
                {"error": {"status": "UNAUTHENTICATED", "message": "bad credential"}},
            )
        ]
    )
    monkeypatch.setattr(settings, "TAVILY_API_KEY", "tvly-invalid")
    monkeypatch.setattr(providers.httpx, "AsyncClient", lambda **_: fake)

    result = await providers.search_tavily("query")

    assert result.status == "credentials_rejected"
    assert result.error_code == "http_401_unauthenticated"
    assert "tvly-invalid" not in (result.error_code or "")
