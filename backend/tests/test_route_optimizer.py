from app.services.route_optimizer import RouteNode, astar_optimize_route


def _plan(mode: str):
    nodes = [
        RouteNode("origin", 0.0, 0.0, "origin"),
        RouteNode(
            "fast",
            0.0,
            0.35,
            "charger",
            effective_power_kw=150.0,
            price_per_kwh=30.0,
            reliability_probability=0.70,
            probability_unavailable=0.20,
            expected_demand=6.0,
        ),
        RouteNode(
            "cheap-reliable",
            0.0,
            0.35,
            "charger",
            effective_power_kw=30.0,
            price_per_kwh=5.0,
            predicted_wait_minutes=5.0,
            reliability_probability=0.98,
            probability_unavailable=0.02,
            expected_demand=1.0,
        ),
        RouteNode("destination", 0.0, 1.0, "destination"),
    ]
    return astar_optimize_route(
        nodes,
        mode=mode,
        battery_kwh=60.0,
        current_soc=0.25,
        target_soc=0.90,
        reserve_soc=0.10,
        efficiency_kwh_per_km=0.20,
        road_distance_factor=1.0,
        drive_minutes_per_km=1.0,
    )


def test_astar_uses_distinct_mode_objectives() -> None:
    fastest = _plan("fastest")
    cheapest = _plan("cheapest")
    balanced = _plan("balanced")
    reliable = _plan("reliable")

    assert fastest is not None
    assert cheapest is not None
    assert balanced is not None
    assert reliable is not None
    assert fastest.node_ids == ("origin", "fast", "destination")
    assert cheapest.node_ids == ("origin", "cheap-reliable", "destination")
    assert balanced.node_ids == ("origin", "cheap-reliable", "destination")
    assert reliable.node_ids == ("origin", "cheap-reliable", "destination")


def test_astar_returns_direct_route_when_charge_is_not_needed() -> None:
    nodes = [
        RouteNode("origin", 18.52, 73.85, "origin"),
        RouteNode(
            "charger",
            18.53,
            73.86,
            "charger",
            effective_power_kw=60.0,
            price_per_kwh=15.0,
        ),
        RouteNode("destination", 18.54, 73.87, "destination"),
    ]
    route = astar_optimize_route(
        nodes,
        mode="balanced",
        battery_kwh=50.0,
        current_soc=0.80,
        target_soc=0.90,
        reserve_soc=0.10,
        efficiency_kwh_per_km=0.18,
    )
    assert route is not None
    assert route.node_ids == ("origin", "destination")
    assert route.charging_minutes == 0


def test_astar_reports_unreachable_when_no_battery_feasible_edge_exists() -> None:
    route = astar_optimize_route(
        [
            RouteNode("origin", 0.0, 0.0, "origin"),
            RouteNode("destination", 0.0, 1.0, "destination"),
        ],
        mode="balanced",
        battery_kwh=20.0,
        current_soc=0.15,
        target_soc=0.80,
        reserve_soc=0.10,
        efficiency_kwh_per_km=0.20,
    )
    assert route is None
