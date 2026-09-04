"""Google Routes adapter with a deterministic, clearly-labelled fallback."""

from __future__ import annotations

import math
import re
from dataclasses import dataclass

import httpx

from app.core.config import settings

ROUTES_COMPUTE_URL = "https://routes.googleapis.com/directions/v2:computeRoutes"


@dataclass(frozen=True)
class DrivingRoute:
    distance_meters: int
    duration_seconds: int
    polyline: str
    status: str


def _haversine_meters(a: tuple[float, float], b: tuple[float, float]) -> float:
    lat1, lon1, lat2, lon2 = map(math.radians, (*a, *b))
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    value = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 6371000.0 * 2 * math.asin(math.sqrt(value))


def _parse_duration_seconds(raw: object) -> int:
    match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)s", str(raw or ""))
    return int(round(float(match.group(1)))) if match else 0


async def compute_driving_route(
    origin: tuple[float, float],
    destination: tuple[float, float],
    intermediates: list[tuple[float, float]] | None = None,
) -> DrivingRoute:
    """Compute one ordered, traffic-aware road route.

    A* decides the charging-stop order. Google Routes is then asked to snap
    that path to the road network and supply the navigation polyline and ETA.
    """
    stops = intermediates or []
    key = settings.GOOGLE_MAPS_API_KEY.strip()
    if key:
        payload = {
            "origin": {"location": {"latLng": {"latitude": origin[0], "longitude": origin[1]}}},
            "destination": {
                "location": {
                    "latLng": {
                        "latitude": destination[0],
                        "longitude": destination[1],
                    }
                }
            },
            "intermediates": [
                {"location": {"latLng": {"latitude": latitude, "longitude": longitude}}}
                for latitude, longitude in stops[:3]
            ],
            "travelMode": "DRIVE",
            "routingPreference": "TRAFFIC_AWARE_OPTIMAL",
            "polylineQuality": "HIGH_QUALITY",
        }
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    ROUTES_COMPUTE_URL,
                    headers={
                        "X-Goog-Api-Key": key,
                        "X-Goog-FieldMask": (
                            "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline"
                        ),
                        "Content-Type": "application/json",
                    },
                    json=payload,
                )
            if response.status_code == 200:
                routes = response.json().get("routes") or []
                if routes:
                    route = routes[0]
                    distance = int(route.get("distanceMeters", 0))
                    duration = _parse_duration_seconds(route.get("duration"))
                    if distance > 0 and duration > 0:
                        return DrivingRoute(
                            distance_meters=distance,
                            duration_seconds=duration,
                            polyline=(route.get("polyline") or {}).get("encodedPolyline", ""),
                            status="ok",
                        )
        except (httpx.HTTPError, TypeError, ValueError):
            pass

    points = [origin, *stops, destination]
    distance_meters = int(sum(_haversine_meters(a, b) for a, b in zip(points, points[1:])) * 1.3)
    return DrivingRoute(
        distance_meters=distance_meters,
        duration_seconds=int(distance_meters / 8.33),
        polyline="",
        status="estimated",
    )
