import pytest

from voltez_ml.geography import haversine_km, nearest_neighbor_ids


def test_haversine_is_symmetric_and_zero_for_same_point() -> None:
    first = (18.5308, 73.8475)
    second = (18.5362, 73.8940)

    assert haversine_km(*first, *first) == pytest.approx(0.0)
    assert haversine_km(*first, *second) == pytest.approx(haversine_km(*second, *first))
    assert 4.0 < haversine_km(*first, *second) < 6.0


def test_nearest_neighbors_use_distance_then_stable_id_tie_break() -> None:
    points = [
        {"id": "center", "lat": 0.0, "lon": 0.0},
        {"id": "east", "lat": 0.0, "lon": 1.0},
        {"id": "west", "lat": 0.0, "lon": -1.0},
        {"id": "far", "lat": 0.0, "lon": 4.0},
    ]

    neighbors = nearest_neighbor_ids(
        points,
        identifier_key="id",
        latitude_key="lat",
        longitude_key="lon",
    )

    assert neighbors["center"] == ["east", "west"]


def test_neighbor_count_must_be_positive() -> None:
    with pytest.raises(ValueError, match="positive"):
        nearest_neighbor_ids(
            [{"id": "only", "lat": 0.0, "lon": 0.0}],
            identifier_key="id",
            latitude_key="lat",
            longitude_key="lon",
            neighbor_count=0,
        )
