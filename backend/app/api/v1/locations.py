import httpx
from fastapi import APIRouter, HTTPException, Query, status
from pydantic import BaseModel, Field

from app.core.config import settings
from app.schemas.location import LocationSearchResult
from app.services.driving_routes import compute_driving_route

router = APIRouter(prefix="/locations", tags=["Location search"])

_NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
_USER_AGENT = "VoltEZ/1.0 (location-search; contact=voltez@example.invalid)"
_PLACES_NEW_AUTOCOMPLETE_URL = "https://places.googleapis.com/v1/places:autocomplete"
_PLACES_NEW_DETAILS_BASE_URL = "https://places.googleapis.com/v1/places"


class RouteComputationResponse(BaseModel):
    distance_meters: int = Field(..., description="Driving distance in meters")
    duration_seconds: int = Field(..., description="Driving duration / ETA in seconds")
    polyline: str = Field(default="", description="Encoded polyline string")
    status: str = Field(default="ok", description="Route status")


async def _search_google(query: str, limit: int) -> list[LocationSearchResult]:
    """Return coordinate-backed Google Places (New) suggestions when configured.

    Calls Google Places API (New) autocomplete followed by Place Details to ensure
    exact latitude & longitude coordinates.
    """
    key = settings.GOOGLE_MAPS_API_KEY.strip()
    if not key:
        return []

    async with httpx.AsyncClient(timeout=4.0, headers={"User-Agent": _USER_AGENT}) as client:
        # 1. Places API (New) Autocomplete
        autocomplete = await client.post(
            _PLACES_NEW_AUTOCOMPLETE_URL,
            headers={
                "X-Goog-Api-Key": key,
                "Content-Type": "application/json",
            },
            json={
                "input": query,
                "includedRegionCodes": ["in"],
            },
        )
        if autocomplete.status_code != 200:
            return []
        payload = autocomplete.json()
        suggestions = payload.get("suggestions") or []
        if not suggestions:
            return []

        results: list[LocationSearchResult] = []
        for item in suggestions[:limit]:
            pred = item.get("placePrediction") or {}
            place_id = pred.get("placeId")
            if not place_id:
                continue

            # 2. Place Details (New)
            details = await client.get(
                f"{_PLACES_NEW_DETAILS_BASE_URL}/{place_id}",
                headers={
                    "X-Goog-Api-Key": key,
                    "X-Goog-FieldMask": "id,displayName,formattedAddress,location,types",
                },
            )
            if details.status_code != 200:
                continue
            detail_payload = details.json()
            loc = detail_payload.get("location") or {}
            if "latitude" not in loc or "longitude" not in loc:
                continue

            display_name = (
                (detail_payload.get("displayName") or {}).get("text")
                or detail_payload.get("formattedAddress")
                or (pred.get("text") or {}).get("text")
                or query
            )

            try:
                results.append(
                    LocationSearchResult(
                        display_name=display_name,
                        latitude=float(loc["latitude"]),
                        longitude=float(loc["longitude"]),
                        place_type=(detail_payload.get("types") or [None])[0],
                        importance=None,
                    )
                )
            except (KeyError, TypeError, ValueError):
                continue
        return results


import re


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
    q: str = Query(..., min_length=3, max_length=200),
    limit: int = Query(default=5, ge=1, le=10),
):
    query = q.strip()
    if len(query) < 3:
        return []

    # Prefer Google Places (New) when configured. A provider outage falls through to the
    # no-key Nominatim adapter so local development and offline environments continue to work.
    try:
        google_results = await _search_google(query, limit)
        if google_results:
            return [
                LocationSearchResult(
                    display_name=_clean_display_name(r.display_name),
                    latitude=r.latitude,
                    longitude=r.longitude,
                    place_type=r.place_type,
                    importance=r.importance,
                )
                for r in google_results
            ]
    except (httpx.HTTPError, ValueError, KeyError, TypeError):
        pass

    params = {
        "q": query,
        "format": "jsonv2",
        "addressdetails": 1,
        "limit": limit,
        "countrycodes": "in",
        "dedupe": 1,
    }
    try:
        async with httpx.AsyncClient(timeout=4.0, headers={"User-Agent": _USER_AGENT}) as client:
            response = await client.get(_NOMINATIM_URL, params=params)
            response.raise_for_status()
            payload = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Location search is temporarily unavailable. Try a fuller address.",
        ) from exc

    results: list[LocationSearchResult] = []
    for item in payload if isinstance(payload, list) else []:
        try:
            raw_display = str(item.get("display_name", ""))
            clean_display = _clean_display_name(raw_display)
            results.append(
                LocationSearchResult(
                    display_name=clean_display,
                    latitude=float(item["lat"]),
                    longitude=float(item["lon"]),
                    place_type=item.get("type"),
                    importance=float(item["importance"])
                    if item.get("importance") is not None
                    else None,
                )
            )
        except (KeyError, TypeError, ValueError):
            continue
    return results


@router.get("/route", response_model=RouteComputationResponse)
async def compute_route(
    origin_lat: float = Query(...),
    origin_lng: float = Query(...),
    dest_lat: float = Query(...),
    dest_lng: float = Query(...),
):
    """Compute live driving route, distance, and duration using Google Routes API."""
    route = await compute_driving_route(
        (origin_lat, origin_lng),
        (dest_lat, dest_lng),
    )
    return RouteComputationResponse(
        distance_meters=route.distance_meters,
        duration_seconds=route.duration_seconds,
        polyline=route.polyline,
        status=route.status,
    )
