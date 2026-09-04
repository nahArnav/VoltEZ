"""Route-aware charger recommendations backed by battery-feasible A*."""

from __future__ import annotations

import math
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.ml.adapters import ml_adapter
from app.repositories.vehicle import vehicle_repo
from app.schemas.charger import ChargerResponse
from app.schemas.recommendation import (
    RecommendationRequest,
    RecommendationResponse,
    RecommendationResult,
    RoutePlan,
    RouteWaypoint,
)
from app.services.charger import charger_service
from app.services.driving_routes import compute_driving_route
from app.services.ml_features import build_availability_features
from app.services.pricing import dynamic_rate_from_signals
from app.services.route_optimizer import (
    RouteNode,
    astar_optimize_route,
    evaluate_path,
    haversine_km,
)

MAX_ASTAR_CHARGERS = 8


def get_float(obj: Any, attr: str, default: float = 0.0) -> float:
    value = getattr(obj, attr, None)
    return float(value) if value is not None else default


def _decode_polyline(encoded: str | None) -> list[tuple[float, float]]:
    """Decode a Google encoded polyline without a third-party dependency."""
    if not encoded:
        return []
    points: list[tuple[float, float]] = []
    latitude = longitude = index = 0
    try:
        while index < len(encoded):
            deltas: list[int] = []
            for _ in range(2):
                result = shift = 0
                while True:
                    value = ord(encoded[index]) - 63
                    index += 1
                    result |= (value & 0x1F) << shift
                    shift += 5
                    if value < 0x20:
                        break
                deltas.append(~(result >> 1) if result & 1 else result >> 1)
            latitude += deltas[0]
            longitude += deltas[1]
            points.append((latitude / 1e5, longitude / 1e5))
    except (IndexError, ValueError):
        return []
    return points


def _point_segment_distance_km(
    point: tuple[float, float],
    start: tuple[float, float],
    end: tuple[float, float],
) -> float:
    """Local equirectangular point-to-segment distance, sufficient for filtering."""
    reference_latitude = math.radians((start[0] + end[0] + point[0]) / 3.0)

    def project(value: tuple[float, float]) -> tuple[float, float]:
        return (
            value[1] * 111.320 * math.cos(reference_latitude),
            value[0] * 110.574,
        )

    px, py = project(point)
    ax, ay = project(start)
    bx, by = project(end)
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay)
    fraction = min(
        max(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy), 0.0),
        1.0,
    )
    return math.hypot(px - (ax + fraction * dx), py - (ay + fraction * dy))


def _distance_to_route_km(
    point: tuple[float, float],
    route: list[tuple[float, float]],
) -> float:
    return min(
        _point_segment_distance_km(point, start, end) for start, end in zip(route, route[1:])
    )


def _best_compatible_port(vehicle: Any, charger: Any) -> tuple[Any | None, float]:
    connector_ids = {connector.id for connector in getattr(vehicle, "connector_types", [])}
    best_port = None
    best_effective_power = 0.0
    for port in charger.ports:
        if not port.is_active or (connector_ids and port.connector_type_id not in connector_ids):
            continue
        station_limit = get_float(port, "max_power_kw")
        is_dc = station_limit > 22.0
        vehicle_limit = get_float(vehicle, "max_dc_kw" if is_dc else "max_ac_kw")
        effective_power = min(station_limit, vehicle_limit or station_limit)
        if effective_power > best_effective_power:
            best_port = port
            best_effective_power = effective_power
    return best_port, best_effective_power


def _vehicle_efficiency_kwh_per_km(vehicle: Any) -> float:
    explicit = get_float(vehicle, "efficiency_wh_per_km") / 1000.0
    if explicit > 0:
        return explicit * 1.08
    battery_kwh = get_float(vehicle, "battery_kwh")
    estimated_range = get_float(vehicle, "estimated_range_km")
    if battery_kwh > 0 and estimated_range > 0:
        return battery_kwh / estimated_range * 1.08
    return 0.18


def _road_distance_from_points(points: list[tuple[float, float]]) -> float:
    route_nodes = [
        RouteNode(str(index), latitude, longitude, "origin")
        for index, (latitude, longitude) in enumerate(points)
    ]
    return sum(haversine_km(a, b) for a, b in zip(route_nodes, route_nodes[1:]))


class RecommendationService:
    @staticmethod
    async def get_recommendations(
        db: AsyncSession,
        req: RecommendationRequest,
        user_id: UUID,
        availability_model: Any = None,
    ) -> RecommendationResponse:
        del availability_model  # Models are loaded once into the verified MLAdapter.
        vehicle = await vehicle_repo.get(db, id=req.vehicle_id)
        if not vehicle or vehicle.user_id != user_id:
            raise HTTPException(status_code=404, detail="Vehicle not found")

        has_destination = (
            req.destination_latitude is not None and req.destination_longitude is not None
        )
        if has_destination:
            raw_candidates = await charger_service.get_route_candidate_chargers(
                db,
                origin_latitude=req.latitude,
                origin_longitude=req.longitude,
                destination_latitude=req.destination_latitude,
                destination_longitude=req.destination_longitude,
                corridor_meters=req.radius_meters,
            )
            route_points = _decode_polyline(req.route_polyline)
            if len(route_points) < 2:
                route_points = [
                    (req.latitude, req.longitude),
                    (req.destination_latitude, req.destination_longitude),
                ]
            direct_km = req.route_distance_km or _road_distance_from_points(route_points)
            corridor_km = min(
                req.radius_meters / 1000.0,
                max(3.0, min(10.0, direct_km * 0.10)),
            )
            raw_candidates = [
                charger
                for charger in raw_candidates
                if _distance_to_route_km(
                    (
                        get_float(charger, "latitude"),
                        get_float(charger, "longitude"),
                    ),
                    route_points,
                )
                <= corridor_km
            ]
            raw_candidates.sort(
                key=lambda charger: _distance_to_route_km(
                    (
                        get_float(charger, "latitude"),
                        get_float(charger, "longitude"),
                    ),
                    route_points,
                )
            )
        else:
            raw_candidates = await charger_service.get_nearby_chargers(
                db,
                latitude=req.latitude,
                longitude=req.longitude,
                radius_meters=int(req.radius_meters),
            )
            direct_km = 0.0

        raw_candidates = raw_candidates[:MAX_ASTAR_CHARGERS]
        battery_kwh = get_float(vehicle, "battery_kwh")
        efficiency = _vehicle_efficiency_kwh_per_km(vehicle)
        origin = RouteNode("origin", req.latitude, req.longitude, "origin")
        destination = (
            RouteNode(
                "destination",
                req.destination_latitude,
                req.destination_longitude,
                "destination",
            )
            if has_destination
            else None
        )
        straight_km = haversine_km(origin, destination) if destination else 0.0
        road_factor = min(max(direct_km / straight_km, 1.0), 2.5) if straight_km else 1.3
        drive_minutes_per_km = (
            min(max(req.route_duration_minutes / direct_km, 0.4), 6.0)
            if req.route_duration_minutes and direct_km > 0
            else 60.0 / 35.0
        )

        charger_nodes: list[RouteNode] = []
        charger_records: dict[str, dict[str, Any]] = {}
        now = datetime.now(UTC)
        for charger in raw_candidates:
            if str(charger.status).lower() != "available":
                continue
            best_port, effective_power = _best_compatible_port(vehicle, charger)
            if best_port is None or effective_power <= 0:
                continue
            latitude = get_float(charger, "latitude")
            longitude = get_float(charger, "longitude")
            provisional_node = RouteNode(str(charger.id), latitude, longitude, "charger")
            distance_from_origin = haversine_km(origin, provisional_node) * road_factor
            target_time = now + timedelta(minutes=distance_from_origin * drive_minutes_per_km)
            features = await build_availability_features(
                db,
                charger.id,
                best_port.id,
                target_time=target_time,
            )
            availability = await ml_adapter.predict_availability(
                db,
                charger.id,
                best_port.id,
                features_df=features,
                target_time=target_time,
            )
            demand = await ml_adapter.predict_demand(db, charger_id=charger.id)
            fallback_reliability = get_float(charger, "reliability_score", 50.0)
            if fallback_reliability > 1.0:
                fallback_reliability /= 100.0
            reliability = await ml_adapter.predict_reliability(
                db,
                charger.id,
                best_port.id,
                features_df=features,
                target_time=target_time,
                fallback_score=fallback_reliability,
            )
            waiting = await ml_adapter.predict_wait_time(
                db,
                charger.id,
                best_port.id,
                features_df=features,
                target_time=target_time,
                availability_prediction=availability,
                demand_prediction=demand,
            )
            dynamic_quote = dynamic_rate_from_signals(
                base_rate=get_float(
                    charger,
                    "price_per_kwh",
                    settings.DEFAULT_PRICE_PER_KWH_INR,
                ),
                expected_demand=demand["expected_demand"],
                probability_unavailable=availability["probability_unavailable"],
                active_ports=sum(1 for port in charger.ports if port.is_active),
                target_time=target_time,
            )
            node = RouteNode(
                str(charger.id),
                latitude,
                longitude,
                "charger",
                effective_power_kw=effective_power,
                price_per_kwh=dynamic_quote.effective_rate,
                predicted_wait_minutes=waiting["wait_minutes"],
                reliability_probability=reliability["probability_reliable"],
                probability_unavailable=availability["probability_unavailable"],
                expected_demand=demand["expected_demand"],
            )
            charger_nodes.append(node)
            charger_records[node.node_id] = {
                "charger": charger,
                "node": node,
                "sources": {
                    "demand": demand["model_version"],
                    "availability": availability["model_version"],
                    "waiting_time": waiting["model_version"],
                    "reliability": reliability["model_version"],
                },
            }

        nodes = [origin, *charger_nodes, *([destination] if destination else [])]
        mode = req.optimization_mode
        path = (
            astar_optimize_route(
                nodes,
                mode=mode,
                battery_kwh=battery_kwh,
                current_soc=req.current_soc,
                target_soc=req.target_soc,
                reserve_soc=req.reserve_soc,
                efficiency_kwh_per_km=efficiency,
                road_distance_factor=road_factor,
                drive_minutes_per_km=drive_minutes_per_km,
            )
            if destination
            else None
        )

        recommendations: list[RecommendationResult] = []
        safe_range_km = battery_kwh * max(0.0, req.current_soc - req.reserve_soc) / efficiency
        destination_index = len(nodes) - 1 if destination else None
        for node_index, node in enumerate(charger_nodes, start=1):
            record = charger_records[node.node_id]
            distance_to_charger = haversine_km(origin, node) * road_factor
            reachable = distance_to_charger <= safe_range_km + 1e-9
            evaluation = (
                evaluate_path(
                    nodes,
                    [0, node_index, destination_index],
                    mode=mode,
                    battery_kwh=battery_kwh,
                    current_soc=req.current_soc,
                    target_soc=req.target_soc,
                    reserve_soc=req.reserve_soc,
                    efficiency_kwh_per_km=efficiency,
                    road_distance_factor=road_factor,
                    drive_minutes_per_km=drive_minutes_per_km,
                )
                if destination_index is not None
                else None
            )
            arrival_soc = max(
                0.0,
                req.current_soc - distance_to_charger * efficiency / battery_kwh,
            )
            charge_kwh = battery_kwh * max(0.0, req.target_soc - arrival_soc)
            charge_minutes = charge_kwh / node.effective_power_kw * 60.0 * 1.15
            estimated_cost = charge_kwh * node.price_per_kwh
            total_minutes = (
                evaluation.total_eta_minutes
                if evaluation
                else distance_to_charger * drive_minutes_per_km
                + charge_minutes
                + node.predicted_wait_minutes
            )
            objective = evaluation.objective_cost if evaluation else 2500.0 + distance_to_charger
            recommendations.append(
                RecommendationResult(
                    charger=ChargerResponse.model_validate(record["charger"]),
                    reachable=reachable,
                    estimated_reach_distance_km=round(safe_range_km, 2),
                    distance_to_charger_km=round(distance_to_charger, 2),
                    estimated_charge_minutes=round(
                        evaluation.charging_minutes if evaluation else charge_minutes,
                        1,
                    ),
                    estimated_cost=round(
                        evaluation.estimated_cost if evaluation else estimated_cost,
                        2,
                    ),
                    estimated_price_per_kwh=node.price_per_kwh,
                    ranking_score=round(max(0.0, 1000.0 - 4.0 * objective), 2),
                    estimated_detour_km=round(
                        max(
                            0.0,
                            (evaluation.distance_km if evaluation else direct_km) - direct_km,
                        ),
                        2,
                    ),
                    predicted_wait_minutes=round(node.predicted_wait_minutes, 1),
                    probability_unavailable=node.probability_unavailable,
                    predicted_demand=node.expected_demand,
                    predicted_reliability=node.reliability_probability,
                    estimated_total_trip_minutes=round(total_minutes, 1),
                    route_feasible=evaluation is not None if destination else reachable,
                    optimization_mode=mode,
                    model_sources=record["sources"],
                )
            )
        recommendations.sort(key=lambda result: result.ranking_score, reverse=True)

        route_plan = None
        if destination:
            route_plan = await _build_route_plan(
                req=req,
                mode=mode,
                path=path,
                charger_records=charger_records,
                direct_km=direct_km,
                drive_minutes_per_km=drive_minutes_per_km,
            )
        return RecommendationResponse(
            recommendations=recommendations[:3],
            route_plan=route_plan,
        )


async def _build_route_plan(
    *,
    req: RecommendationRequest,
    mode: str,
    path: Any,
    charger_records: dict[str, dict[str, Any]],
    direct_km: float,
    drive_minutes_per_km: float,
) -> RoutePlan:
    if path is None:
        drive_minutes = direct_km * drive_minutes_per_km
        return RoutePlan(
            mode=mode,
            reachable=False,
            requires_charging=False,
            distance_km=round(direct_km, 2),
            drive_minutes=round(drive_minutes, 1),
            charging_minutes=0.0,
            waiting_minutes=0.0,
            total_eta_minutes=round(drive_minutes, 1),
            estimated_cost=0.0,
            reliability_probability=0.0,
            availability_probability=0.0,
            expected_demand=0.0,
            navigation_provider="unavailable",
        )

    stop_ids = [node_id for node_id in path.node_ids if node_id in charger_records]
    stop_nodes = [charger_records[node_id]["node"] for node_id in stop_ids]
    road_route = await compute_driving_route(
        (req.latitude, req.longitude),
        (req.destination_latitude, req.destination_longitude),
        [(node.latitude, node.longitude) for node in stop_nodes],
    )
    waypoints = [
        RouteWaypoint(
            charger_id=record["charger"].id,
            name=record["charger"].name,
            latitude=record["node"].latitude,
            longitude=record["node"].longitude,
        )
        for node_id in stop_ids
        for record in [charger_records[node_id]]
    ]
    source_groups: dict[str, set[str]] = {
        "demand": set(),
        "availability": set(),
        "waiting_time": set(),
        "reliability": set(),
    }
    for node_id in stop_ids:
        for family, source in charger_records[node_id]["sources"].items():
            source_groups[family].add(source)
    model_sources = {
        family: ",".join(sorted(sources)) if sources else "not-required"
        for family, sources in source_groups.items()
    }
    drive_minutes = road_route.duration_seconds / 60.0
    return RoutePlan(
        mode=mode,
        reachable=True,
        requires_charging=bool(waypoints),
        waypoints=waypoints,
        distance_km=round(road_route.distance_meters / 1000.0, 2),
        drive_minutes=round(drive_minutes, 1),
        charging_minutes=round(path.charging_minutes, 1),
        waiting_minutes=round(path.waiting_minutes, 1),
        total_eta_minutes=round(
            drive_minutes + path.charging_minutes + path.waiting_minutes,
            1,
        ),
        estimated_cost=round(path.estimated_cost, 2),
        reliability_probability=path.reliability_probability,
        availability_probability=path.availability_probability,
        expected_demand=path.expected_demand,
        polyline=road_route.polyline,
        navigation_provider=("google_routes" if road_route.status == "ok" else "estimated"),
        model_sources=model_sources,
    )


recommendation_service = RecommendationService()
