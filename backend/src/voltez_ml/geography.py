"""Small dependency-free geographic helpers shared by simulation and feature code."""

from __future__ import annotations

import math
from collections.abc import Mapping, Sequence
from typing import Any


def haversine_km(
    first_latitude: float,
    first_longitude: float,
    second_latitude: float,
    second_longitude: float,
) -> float:
    """Return great-circle distance between two latitude/longitude points."""

    earth_radius_km = 6371.0088
    latitude_delta = math.radians(second_latitude - first_latitude)
    longitude_delta = math.radians(second_longitude - first_longitude)
    first_latitude_radians = math.radians(first_latitude)
    second_latitude_radians = math.radians(second_latitude)
    haversine_value = (
        math.sin(latitude_delta / 2) ** 2
        + math.cos(first_latitude_radians)
        * math.cos(second_latitude_radians)
        * math.sin(longitude_delta / 2) ** 2
    )
    return 2 * earth_radius_km * math.asin(math.sqrt(haversine_value))


def nearest_neighbor_ids(
    points: Sequence[Mapping[str, Any]],
    *,
    identifier_key: str,
    latitude_key: str,
    longitude_key: str,
    neighbor_count: int = 2,
) -> dict[str, list[str]]:
    """Map each point to its geographically nearest distinct point IDs."""

    if neighbor_count <= 0:
        raise ValueError("neighbor_count must be positive")
    result: dict[str, list[str]] = {}
    for point in points:
        identifier = str(point[identifier_key])
        distances = [
            (
                haversine_km(
                    float(point[latitude_key]),
                    float(point[longitude_key]),
                    float(candidate[latitude_key]),
                    float(candidate[longitude_key]),
                ),
                str(candidate[identifier_key]),
            )
            for candidate in points
            if str(candidate[identifier_key]) != identifier
        ]
        distances.sort(key=lambda item: (item[0], item[1]))
        result[identifier] = [candidate_id for _, candidate_id in distances[:neighbor_count]]
    return result
