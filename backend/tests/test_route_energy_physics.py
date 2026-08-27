import pytest
from pydantic import ValidationError

from voltez_ml.route_energy import (
    RoutePhysicsInput,
    VehiclePhysicsInput,
    assess_reachability,
    estimate_physics_energy,
)


@pytest.fixture
def vehicle() -> VehiclePhysicsInput:
    return VehiclePhysicsInput(
        battery_capacity_kwh=60,
        usable_capacity_fraction=0.95,
        total_mass_kg=1_750,
        drag_area_m2=0.65,
        rolling_resistance_coefficient=0.011,
        drivetrain_efficiency=0.90,
        regenerative_braking_efficiency=0.65,
    )


def test_flat_route_energy_scales_with_distance_at_equal_speed(
    vehicle: VehiclePhysicsInput,
) -> None:
    short = estimate_physics_energy(
        vehicle,
        RoutePhysicsInput(distance_km=20, duration_minutes=30, full_stop_count=4),
    )
    long = estimate_physics_energy(
        vehicle,
        RoutePhysicsInput(distance_km=40, duration_minutes=60, full_stop_count=8),
    )

    assert long.estimated_battery_energy_kwh == pytest.approx(
        2 * short.estimated_battery_energy_kwh
    )


def test_climb_headwind_and_accessory_load_raise_energy(
    vehicle: VehiclePhysicsInput,
) -> None:
    base = estimate_physics_energy(
        vehicle,
        RoutePhysicsInput(distance_km=30, duration_minutes=45),
    )
    difficult = estimate_physics_energy(
        vehicle,
        RoutePhysicsInput(
            distance_km=30,
            duration_minutes=45,
            elevation_gain_m=350,
            headwind_mps=6,
            auxiliary_power_kw=2.5,
        ),
    )

    assert difficult.climbing_kwh > 0
    assert difficult.aerodynamic_kwh > base.aerodynamic_kwh
    assert difficult.auxiliary_kwh > base.auxiliary_kwh
    assert difficult.estimated_battery_energy_kwh > base.estimated_battery_energy_kwh


def test_regeneration_never_creates_negative_consumption(
    vehicle: VehiclePhysicsInput,
) -> None:
    descent = estimate_physics_energy(
        vehicle,
        RoutePhysicsInput(
            distance_km=5,
            duration_minutes=20,
            elevation_loss_m=2_000,
            auxiliary_power_kw=0,
        ),
    )

    assert descent.descent_regen_credit_kwh > 0
    assert descent.estimated_battery_energy_kwh == 0


def test_reachability_uses_conservative_energy_and_reserve(
    vehicle: VehiclePhysicsInput,
) -> None:
    reachable = assess_reachability(
        vehicle,
        current_soc_percent=70,
        reserve_soc_percent=15,
        expected_energy_kwh=18,
        conservative_energy_kwh=22,
    )
    unreachable = assess_reachability(
        vehicle,
        current_soc_percent=35,
        reserve_soc_percent=15,
        expected_energy_kwh=10,
        conservative_energy_kwh=13,
    )

    assert reachable.status == "reachable"
    assert reachable.conservative_arrival_soc_percent >= 15
    assert unreachable.status == "unreachable"
    assert unreachable.conservative_arrival_soc_percent < 15


def test_invalid_route_and_soc_are_rejected(vehicle: VehiclePhysicsInput) -> None:
    with pytest.raises(ValidationError, match="mean speed"):
        RoutePhysicsInput(distance_km=100, duration_minutes=10)
    with pytest.raises(ValueError, match="reserve"):
        assess_reachability(
            vehicle,
            current_soc_percent=20,
            reserve_soc_percent=20,
            expected_energy_kwh=1,
            conservative_energy_kwh=2,
        )
