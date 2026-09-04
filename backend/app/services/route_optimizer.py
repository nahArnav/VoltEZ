"""Battery-aware A* route optimisation for EV charging trips.

The graph is deliberately small: origin, destination, and a bounded set of
compatible chargers near the road corridor.  Each edge is accepted only when
the vehicle can traverse it while preserving the requested reserve SoC.
Charging, queue, price, availability, demand, and reliability signals are
charged as node costs when A* visits a station.
"""

from __future__ import annotations

import heapq
import math
from dataclasses import dataclass
from itertools import count
from typing import Literal

RouteMode = Literal["fastest", "cheapest", "balanced", "reliable"]


@dataclass(frozen=True)
class RouteNode:
    node_id: str
    latitude: float
    longitude: float
    kind: Literal["origin", "charger", "destination"]
    effective_power_kw: float = 0.0
    price_per_kwh: float = 0.0
    predicted_wait_minutes: float = 0.0
    reliability_probability: float = 1.0
    probability_unavailable: float = 0.0
    expected_demand: float = 0.0


@dataclass(frozen=True)
class PathEvaluation:
    node_ids: tuple[str, ...]
    distance_km: float
    drive_minutes: float
    charging_minutes: float
    waiting_minutes: float
    estimated_cost: float
    reliability_probability: float
    availability_probability: float
    expected_demand: float
    total_eta_minutes: float
    objective_cost: float
    energy_kwh: float


def haversine_km(a: RouteNode, b: RouteNode) -> float:
    radius_km = 6371.0
    lat1, lon1, lat2, lon2 = map(
        math.radians,
        (a.latitude, a.longitude, b.latitude, b.longitude),
    )
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    value = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return radius_km * 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value))


def _edge_metrics(
    source: RouteNode,
    target: RouteNode,
    *,
    battery_kwh: float,
    source_soc: float,
    target_soc: float,
    reserve_soc: float,
    efficiency_kwh_per_km: float,
    road_distance_factor: float,
    drive_minutes_per_km: float,
) -> dict[str, float] | None:
    distance_km = haversine_km(source, target) * road_distance_factor
    energy_kwh = distance_km * efficiency_kwh_per_km
    usable_kwh = battery_kwh * max(0.0, source_soc - reserve_soc)
    if energy_kwh > usable_kwh + 1e-9:
        return None

    drive_minutes = distance_km * drive_minutes_per_km
    arrival_soc = max(0.0, source_soc - energy_kwh / battery_kwh)
    charge_kwh = charge_minutes = cost = wait_minutes = 0.0
    reliability = availability = 1.0
    demand = 0.0
    if target.kind == "charger":
        charge_kwh = battery_kwh * max(0.0, target_soc - arrival_soc)
        if target.effective_power_kw <= 0:
            return None
        # A bounded taper/loss factor is more realistic than ideal kW division.
        charge_minutes = charge_kwh / target.effective_power_kw * 60.0 * 1.15
        cost = charge_kwh * max(0.0, target.price_per_kwh)
        wait_minutes = max(0.0, target.predicted_wait_minutes)
        reliability = min(max(target.reliability_probability, 0.0), 1.0)
        availability = 1.0 - min(max(target.probability_unavailable, 0.0), 1.0)
        demand = max(0.0, target.expected_demand)

    return {
        "distance_km": distance_km,
        "drive_minutes": drive_minutes,
        "energy_kwh": energy_kwh,
        "charge_minutes": charge_minutes,
        "wait_minutes": wait_minutes,
        "cost": cost,
        "reliability": reliability,
        "availability": availability,
        "demand": demand,
    }


def _objective(mode: RouteMode, metrics: dict[str, float]) -> float:
    service_minutes = metrics["drive_minutes"] + metrics["charge_minutes"] + metrics["wait_minutes"]
    reliability_risk = (1.0 - metrics["reliability"]) * 100.0
    availability_risk = (1.0 - metrics["availability"]) * 100.0
    demand_risk = min(metrics["demand"] / 8.0, 1.0) * 20.0
    risk = reliability_risk + availability_risk + demand_risk

    if mode == "fastest":
        return service_minutes + 0.08 * risk + 0.01 * metrics["cost"]
    if mode == "cheapest":
        return metrics["cost"] + 0.08 * service_minutes + 0.06 * risk
    if mode == "reliable":
        return risk + 0.25 * service_minutes + 0.02 * metrics["cost"]
    return 0.55 * service_minutes + 0.35 * metrics["cost"] + 0.35 * risk


def evaluate_path(
    nodes: list[RouteNode],
    node_indices: list[int],
    *,
    mode: RouteMode,
    battery_kwh: float,
    current_soc: float,
    target_soc: float,
    reserve_soc: float,
    efficiency_kwh_per_km: float,
    road_distance_factor: float,
    drive_minutes_per_km: float,
) -> PathEvaluation | None:
    totals = {
        "distance_km": 0.0,
        "drive_minutes": 0.0,
        "energy_kwh": 0.0,
        "charge_minutes": 0.0,
        "wait_minutes": 0.0,
        "cost": 0.0,
        "demand": 0.0,
    }
    reliability = availability = 1.0
    source_soc = current_soc
    station_count = 0

    for source_index, target_index in zip(node_indices, node_indices[1:]):
        source = nodes[source_index]
        target = nodes[target_index]
        edge = _edge_metrics(
            source,
            target,
            battery_kwh=battery_kwh,
            source_soc=source_soc,
            target_soc=target_soc,
            reserve_soc=reserve_soc,
            efficiency_kwh_per_km=efficiency_kwh_per_km,
            road_distance_factor=road_distance_factor,
            drive_minutes_per_km=drive_minutes_per_km,
        )
        if edge is None:
            return None
        for key in totals:
            totals[key] += edge[key]
        if target.kind == "charger":
            station_count += 1
            reliability *= edge["reliability"]
            availability *= edge["availability"]
            source_soc = target_soc
        else:
            source_soc = max(0.0, source_soc - edge["energy_kwh"] / battery_kwh)

    aggregate = {
        "drive_minutes": totals["drive_minutes"],
        "charge_minutes": totals["charge_minutes"],
        "wait_minutes": totals["wait_minutes"],
        "cost": totals["cost"],
        "reliability": reliability,
        "availability": availability,
        "demand": totals["demand"] / station_count if station_count else 0.0,
    }
    return PathEvaluation(
        node_ids=tuple(nodes[index].node_id for index in node_indices),
        distance_km=totals["distance_km"],
        drive_minutes=totals["drive_minutes"],
        charging_minutes=totals["charge_minutes"],
        waiting_minutes=totals["wait_minutes"],
        estimated_cost=totals["cost"],
        reliability_probability=reliability,
        availability_probability=availability,
        expected_demand=aggregate["demand"],
        total_eta_minutes=(
            totals["drive_minutes"] + totals["charge_minutes"] + totals["wait_minutes"]
        ),
        objective_cost=_objective(mode, aggregate),
        energy_kwh=totals["energy_kwh"],
    )


def astar_optimize_route(
    nodes: list[RouteNode],
    *,
    mode: RouteMode,
    battery_kwh: float,
    current_soc: float,
    target_soc: float,
    reserve_soc: float,
    efficiency_kwh_per_km: float,
    road_distance_factor: float = 1.3,
    drive_minutes_per_km: float = 60.0 / 35.0,
    max_charging_stops: int = 3,
) -> PathEvaluation | None:
    """Return the lowest-cost battery-feasible path using A*.

    ``nodes`` must contain the origin first and destination last. Charger SoC
    is deterministic after service (``target_soc``), so ``(node, stop_count)``
    is a sufficient state and keeps the search fast and auditable.
    """
    if len(nodes) < 2 or nodes[0].kind != "origin" or nodes[-1].kind != "destination":
        raise ValueError("nodes must start with origin and end with destination")
    if battery_kwh <= 0 or efficiency_kwh_per_km <= 0:
        raise ValueError("battery and efficiency must be positive")
    if not (0 <= reserve_soc < target_soc <= 1 and 0 <= current_soc <= 1):
        raise ValueError("invalid SoC configuration")

    destination_index = len(nodes) - 1
    start_state = (0, 0)
    best_cost: dict[tuple[int, int], float] = {start_state: 0.0}
    previous: dict[tuple[int, int], tuple[int, int]] = {}
    queue: list[tuple[float, int, float, tuple[int, int]]] = []
    sequence = count()

    def heuristic(node_index: int) -> float:
        remaining_drive = (
            haversine_km(nodes[node_index], nodes[destination_index])
            * road_distance_factor
            * drive_minutes_per_km
        )
        if mode == "fastest":
            return remaining_drive
        if mode == "balanced":
            return 0.55 * remaining_drive
        if mode == "cheapest":
            return 0.08 * remaining_drive
        return 0.25 * remaining_drive

    heapq.heappush(queue, (heuristic(0), next(sequence), 0.0, start_state))

    while queue:
        _, _, cost_so_far, state = heapq.heappop(queue)
        node_index, stop_count = state
        if cost_so_far > best_cost.get(state, math.inf) + 1e-9:
            continue
        if node_index == destination_index:
            path_indices = [node_index]
            cursor = state
            while cursor != start_state:
                cursor = previous[cursor]
                path_indices.append(cursor[0])
            path_indices.reverse()
            return evaluate_path(
                nodes,
                path_indices,
                mode=mode,
                battery_kwh=battery_kwh,
                current_soc=current_soc,
                target_soc=target_soc,
                reserve_soc=reserve_soc,
                efficiency_kwh_per_km=efficiency_kwh_per_km,
                road_distance_factor=road_distance_factor,
                drive_minutes_per_km=drive_minutes_per_km,
            )

        source = nodes[node_index]
        source_soc = current_soc if source.kind == "origin" else target_soc
        for target_index, target in enumerate(nodes):
            if target_index == node_index or target.kind == "origin":
                continue
            next_stop_count = stop_count + int(target.kind == "charger")
            if next_stop_count > max_charging_stops:
                continue
            edge = _edge_metrics(
                source,
                target,
                battery_kwh=battery_kwh,
                source_soc=source_soc,
                target_soc=target_soc,
                reserve_soc=reserve_soc,
                efficiency_kwh_per_km=efficiency_kwh_per_km,
                road_distance_factor=road_distance_factor,
                drive_minutes_per_km=drive_minutes_per_km,
            )
            if edge is None:
                continue
            next_state = (target_index, next_stop_count)
            candidate_cost = cost_so_far + _objective(mode, edge)
            if candidate_cost + 1e-9 >= best_cost.get(next_state, math.inf):
                continue
            best_cost[next_state] = candidate_cost
            previous[next_state] = state
            heapq.heappush(
                queue,
                (
                    candidate_cost + heuristic(target_index),
                    next(sequence),
                    candidate_cost,
                    next_state,
                ),
            )
    return None
