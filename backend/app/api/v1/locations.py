import re
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import httpx
from fastapi import APIRouter, HTTPException, Query, Request, status
from pydantic import BaseModel, Field

from app.core.config import settings
from app.core.logging import get_logger
from app.schemas.location import LocationSearchResult
from app.services.driving_routes import compute_driving_route

router = APIRouter(prefix="/locations", tags=["Location search"])

_PLACES_TEXT_SEARCH_URL = "https://places.googleapis.com/v1/places:searchText"
logger = get_logger("location_search")


@asynccontextmanager
async def _places_client(
    client: httpx.AsyncClient | None,
) -> AsyncIterator[httpx.AsyncClient]:
    if client is not None:
        yield client
        return
    async with httpx.AsyncClient(timeout=4.0) as owned_client:
        yield owned_client


class RouteComputationResponse(BaseModel):
    distance_meters: int = Field(..., description="Driving distance in meters")
    duration_seconds: int = Field(..., description="Driving duration / ETA in seconds")
    polyline: str = Field(default="", description="Encoded polyline string")
    status: str = Field(default="ok", description="Route status")


async def _search_google(
    query: str,
    limit: int,
    *,
    client: httpx.AsyncClient | None = None,
) -> list[LocationSearchResult]:
    """Return coordinate-backed Google Places (New) search results.

    Text Search returns coordinates in the same response. The previous
    autocomplete implementation fetched Place Details once per suggestion,
    multiplying latency, billable calls and quota pressure.
    """
    key = settings.GOOGLE_MAPS_API_KEY.strip()
    if not key:
        raise RuntimeError("GOOGLE_MAPS_API_KEY is not configured")

    async with _places_client(client) as active_client:
        response = await active_client.post(
            _PLACES_TEXT_SEARCH_URL,
            headers={
                "X-Goog-Api-Key": key,
                "X-Goog-FieldMask": (
                    "places.id,places.displayName,places.formattedAddress,places.location"
                ),
                "Content-Type": "application/json",
            },
            json={
                "textQuery": query,
                "pageSize": limit,
                "languageCode": "en",
                "regionCode": "IN",
            },
            timeout=4.0,
        )
        if response.status_code != 200:
            logger.warning(
                "Google Places Text Search failed status=%d",
                response.status_code,
            )
            response.raise_for_status()

        results: list[LocationSearchResult] = []
        for place in response.json().get("places") or []:
            loc = place.get("location") or {}
            if "latitude" not in loc or "longitude" not in loc:
                continue

            display_name = (
                (place.get("displayName") or {}).get("text")
                or place.get("formattedAddress")
                or query
            )

            try:
                results.append(
                    LocationSearchResult(
                        display_name=display_name,
                        latitude=float(loc["latitude"]),
                        longitude=float(loc["longitude"]),
                        place_type=None,
                        importance=None,
                    )
                )
            except (KeyError, TypeError, ValueError):
                continue
        return results


def _clean_display_name(raw_name: str) -> str:
    if not raw_name:
        return ""
    # Strip leading Plus Code (e.g. "FV38+53H, Katraj, Pune..." -> "Katraj, Pune...")
    cleaned = re.sub(
        r"^[A-Z0-9]{2,8}\+[A-Z0-9]{2,4}\s*,\s*", "", raw_name, flags=re.IGNORECASE
    ).strip()
    parts = [p.strip() for p in cleaned.split(",") if p.strip()]
    seen = set()
    deduped = []
    for part in parts:
        lower = part.lower()
        if lower not in seen and not re.match(
            r"^[A-Z0-9]{2,8}\+[A-Z0-9]{2,4}$", part, re.IGNORECASE
        ):
            seen.add(lower)
            deduped.append(part)
    return ", ".join(deduped) if deduped else raw_name


@router.get("/search", response_model=list[LocationSearchResult])
async def search_locations(
    request: Request,
    q: str = Query(..., min_length=3, max_length=200),
    limit: int = Query(default=5, ge=1, le=10),
):
    query = q.strip()
    if len(query) < 3:
        return []

    # Google Places is the production provider. The Android client has an OS
    # geocoder fallback; returning quickly here is preferable to proxying the
    # public Nominatim endpoint, whose policy explicitly forbids autocomplete.
    try:
        google_results = await _search_google(
            query,
            limit,
            client=getattr(request.app.state, "http_client", None),
        )
    except (httpx.HTTPError, RuntimeError, ValueError, KeyError, TypeError) as exc:
        logger.warning("Location provider unavailable error=%s", type(exc).__name__)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google Places search is unavailable. Check Places API (New) configuration.",
        ) from exc

    return [
        LocationSearchResult(
            display_name=_clean_display_name(result.display_name),
            latitude=result.latitude,
            longitude=result.longitude,
            place_type=result.place_type,
            importance=result.importance,
        )
        for result in google_results
    ]


@router.get("/route", response_model=RouteComputationResponse)
async def compute_route(
    request: Request,
    origin_lat: float = Query(...),
    origin_lng: float = Query(...),
    dest_lat: float = Query(...),
    dest_lng: float = Query(...),
):
    """Compute live driving route, distance, and duration using Google Routes API."""
    route = await compute_driving_route(
        (origin_lat, origin_lng),
        (dest_lat, dest_lng),
        client=getattr(request.app.state, "http_client", None),
    )
    return RouteComputationResponse(
        distance_meters=route.distance_meters,
        duration_seconds=route.duration_seconds,
        polyline=route.polyline,
        status=route.status,
    )
