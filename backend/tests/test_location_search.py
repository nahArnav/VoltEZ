from typing import Any

import httpx
import pytest

from app.api.v1 import locations
from app.core.config import settings


class _FakePlacesClient:
    def __init__(self, response: httpx.Response):
        self.response = response
        self.calls: list[dict[str, Any]] = []

    async def post(self, url: str, **kwargs) -> httpx.Response:
        self.calls.append({"url": url, **kwargs})
        return self.response


def _response(status_code: int, payload: dict[str, Any]) -> httpx.Response:
    return httpx.Response(
        status_code,
        json=payload,
        request=httpx.Request("POST", locations._PLACES_TEXT_SEARCH_URL),
    )


@pytest.mark.asyncio
async def test_google_location_search_uses_one_coordinate_backed_request(monkeypatch) -> None:
    client = _FakePlacesClient(
        _response(
            200,
            {
                "places": [
                    {
                        "id": "place-1",
                        "displayName": {"text": "Pune Railway Station"},
                        "formattedAddress": "Agarkar Nagar, Pune, Maharashtra",
                        "location": {"latitude": 18.5289, "longitude": 73.8744},
                    }
                ]
            },
        )
    )
    monkeypatch.setattr(settings, "GOOGLE_MAPS_API_KEY", "maps-test-key")

    results = await locations._search_google("Pune railway station", 3, client=client)

    assert len(client.calls) == 1
    assert client.calls[0]["url"] == locations._PLACES_TEXT_SEARCH_URL
    assert client.calls[0]["headers"]["X-Goog-Api-Key"] == "maps-test-key"
    assert "places.location" in client.calls[0]["headers"]["X-Goog-FieldMask"]
    assert client.calls[0]["json"]["pageSize"] == 3
    assert results[0].display_name == "Pune Railway Station"
    assert results[0].latitude == 18.5289
    assert results[0].longitude == 73.8744


@pytest.mark.asyncio
async def test_google_location_search_surfaces_provider_rate_limit(monkeypatch) -> None:
    client = _FakePlacesClient(_response(429, {"error": {"status": "RESOURCE_EXHAUSTED"}}))
    monkeypatch.setattr(settings, "GOOGLE_MAPS_API_KEY", "maps-test-key")

    with pytest.raises(httpx.HTTPStatusError):
        await locations._search_google("Pune", 5, client=client)
