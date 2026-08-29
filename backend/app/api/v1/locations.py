import httpx
from fastapi import APIRouter, HTTPException, Query, status

from app.core.config import settings
from app.schemas.location import LocationSearchResult

router = APIRouter(prefix="/locations", tags=["Location search"])

# Nominatim is used as the no-key development geocoder.  Keeping this behind
# our API prevents exposing provider details to Flutter and lets deployment
# swap in Google Places or another India-compliant provider later.
_NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
_USER_AGENT = "VoltEZ/1.0 (location-search; contact=voltez@example.invalid)"
_GOOGLE_AUTOCOMPLETE_URL = "https://maps.googleapis.com/maps/api/place/autocomplete/json"
_GOOGLE_DETAILS_URL = "https://maps.googleapis.com/maps/api/place/details/json"


async def _search_google(query: str, limit: int) -> list[LocationSearchResult]:
    """Return coordinate-backed Google Places suggestions when configured.

    Autocomplete rows do not contain coordinates, so each candidate is
    resolved through Places Details before it reaches Flutter. This prevents
    persisting a vague label as if it were a real map point.
    """
    key = settings.GOOGLE_MAPS_API_KEY.strip()
    if not key:
        return []

    async with httpx.AsyncClient(
        timeout=4.0, headers={"User-Agent": _USER_AGENT}
    ) as client:
        autocomplete = await client.get(
            _GOOGLE_AUTOCOMPLETE_URL,
            params={
                "input": query,
                "components": "country:in",
                "language": "en",
                "key": key,
            },
        )
        autocomplete.raise_for_status()
        payload = autocomplete.json()
        if payload.get("status") not in {"OK", "ZERO_RESULTS"}:
            return []

        results: list[LocationSearchResult] = []
        for prediction in (payload.get("predictions") or [])[:limit]:
            place_id = prediction.get("place_id")
            if not place_id:
                continue
            details = await client.get(
                _GOOGLE_DETAILS_URL,
                params={
                    "place_id": place_id,
                    "fields": "geometry,formatted_address,name,types",
                    "key": key,
                },
            )
            details.raise_for_status()
            detail_payload = details.json()
            if detail_payload.get("status") != "OK":
                continue
            result = detail_payload.get("result") or {}
            location = (result.get("geometry") or {}).get("location") or {}
            try:
                results.append(
                    LocationSearchResult(
                        display_name=(
                            result.get("formatted_address")
                            or result.get("name")
                            or prediction.get("description")
                        ),
                        latitude=float(location["lat"]),
                        longitude=float(location["lng"]),
                        place_type=(result.get("types") or [None])[0],
                        importance=None,
                    )
                )
            except (KeyError, TypeError, ValueError):
                continue
        return results


@router.get("/search", response_model=list[LocationSearchResult])
async def search_locations(
    q: str = Query(..., min_length=3, max_length=200),
    limit: int = Query(default=5, ge=1, le=10),
):
    query = q.strip()
    if len(query) < 3:
        return []

    # Prefer Places when configured. A provider outage falls through to the
    # no-key Nominatim adapter so local development and existing deployments
    # continue to work.
    try:
        google_results = await _search_google(query, limit)
        if google_results:
            return google_results
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
            results.append(
                LocationSearchResult(
                    display_name=str(item["display_name"]),
                    latitude=float(item["lat"]),
                    longitude=float(item["lon"]),
                    place_type=item.get("type"),
                    importance=float(item["importance"]) if item.get("importance") is not None else None,
                )
            )
        except (KeyError, TypeError, ValueError):
            # A malformed provider row must not break otherwise useful results.
            continue
    return results
