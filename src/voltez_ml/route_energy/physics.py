"""Auditable physics baseline and safety-first reachability logic for Model 5.

This module is intentionally not an ML trainer. It freezes the deterministic baseline that a
future residual model must beat and gives the application a safe fallback when an ML artifact is
missing or an input is outside its contract.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

JOULES_PER_KWH = 3_600_000.0
STANDARD_GRAVITY_M_S2 = 9.80665


class StrictPhysicsModel(BaseModel):
    """Reject accidental or misspelled physics inputs."""

    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)


class VehiclePhysicsInput(StrictPhysicsModel):
    """Vehicle properties known before route planning begins."""

    battery_capacity_kwh: float = Field(gt=0, le=250)
    usable_capacity_fraction: float = Field(default=0.95, gt=0.5, le=1.0)
    total_mass_kg: float = Field(gt=40, le=7_500)
    drag_area_m2: float = Field(gt=0.05, le=8.0)
    rolling_resistance_coefficient: float = Field(gt=0.001, le=0.05)
    drivetrain_efficiency: float = Field(gt=0.5, le=1.0)
    regenerative_braking_efficiency: float = Field(ge=0.0, le=0.95)


class RoutePhysicsInput(StrictPhysicsModel):
    """Route and environment values available at the route snapshot time."""

    distance_km: float = Field(gt=0, le=2_000)
    duration_minutes: float = Field(gt=0, le=2_000)
    elevation_gain_m: float = Field(default=0, ge=0, le=20_000)
    elevation_loss_m: float = Field(default=0, ge=0, le=20_000)
    full_stop_count: int = Field(default=0, ge=0, le=10_000)
    auxiliary_power_kw: float = Field(default=0.7, ge=0, le=30)
    headwind_mps: float = Field(default=0, ge=-50, le=50)
    air_density_kg_m3: float = Field(default=1.225, ge=0.7, le=1.6)

    @model_validator(mode="after")
    def reject_physically_implausible_mean_speed(self) -> RoutePhysicsInput:
        mean_speed_kph = self.distance_km / (self.duration_minutes / 60)
        if mean_speed_kph > 180:
            raise ValueError("route distance and duration imply a mean speed above 180 km/h")
        return self


class PhysicsEstimate(StrictPhysicsModel):
    """Energy breakdown returned by the deterministic baseline."""

    rolling_kwh: float = Field(ge=0)
    aerodynamic_kwh: float = Field(ge=0)
    climbing_kwh: float = Field(ge=0)
    stop_start_kwh: float = Field(ge=0)
    auxiliary_kwh: float = Field(ge=0)
    descent_regen_credit_kwh: float = Field(ge=0)
    estimated_battery_energy_kwh: float = Field(ge=0)
    mean_speed_kph: float = Field(ge=0)


class ReachabilityAssessment(StrictPhysicsModel):
    """Safety-oriented translation from energy prediction to a route decision."""

    status: Literal["reachable", "borderline", "unreachable"]
    expected_arrival_soc_percent: float
    conservative_arrival_soc_percent: float
    energy_available_above_reserve_kwh: float
    conservative_energy_required_kwh: float
    safety_margin_kwh: float


def estimate_physics_energy(
    vehicle: VehiclePhysicsInput,
    route: RoutePhysicsInput,
) -> PhysicsEstimate:
    """Estimate battery energy from auditable force and power components.

    The baseline uses route averages, so it cannot represent every second of real driving. A
    future ML model will predict the residual between measured energy and this estimate rather
    than relearning basic physical laws from scratch.
    """

    distance_m = route.distance_km * 1_000
    duration_hours = route.duration_minutes / 60
    mean_speed_mps = distance_m / (route.duration_minutes * 60)
    effective_air_speed_mps = max(0.0, mean_speed_mps + route.headwind_mps)

    rolling_wheel_kwh = (
        vehicle.rolling_resistance_coefficient
        * vehicle.total_mass_kg
        * STANDARD_GRAVITY_M_S2
        * distance_m
        / JOULES_PER_KWH
    )
    aerodynamic_wheel_kwh = (
        0.5
        * route.air_density_kg_m3
        * vehicle.drag_area_m2
        * effective_air_speed_mps**2
        * distance_m
        / JOULES_PER_KWH
    )
    climbing_wheel_kwh = (
        vehicle.total_mass_kg
        * STANDARD_GRAVITY_M_S2
        * route.elevation_gain_m
        / JOULES_PER_KWH
    )

    # Each full stop loses kinetic energy. Acceleration draws through drivetrain losses while a
    # bounded portion of the following deceleration can return through regenerative braking.
    kinetic_kwh_per_stop = (
        0.5 * vehicle.total_mass_kg * mean_speed_mps**2 / JOULES_PER_KWH
    )
    stop_start_kwh = route.full_stop_count * kinetic_kwh_per_stop * (
        1 / vehicle.drivetrain_efficiency - vehicle.regenerative_braking_efficiency
    )

    traction_battery_kwh = (
        rolling_wheel_kwh + aerodynamic_wheel_kwh + climbing_wheel_kwh
    ) / vehicle.drivetrain_efficiency
    auxiliary_kwh = route.auxiliary_power_kw * duration_hours
    descent_regen_credit_kwh = (
        vehicle.total_mass_kg
        * STANDARD_GRAVITY_M_S2
        * route.elevation_loss_m
        / JOULES_PER_KWH
        * vehicle.regenerative_braking_efficiency
    )
    estimated = max(
        0.0,
        traction_battery_kwh
        + stop_start_kwh
        + auxiliary_kwh
        - descent_regen_credit_kwh,
    )
    return PhysicsEstimate(
        rolling_kwh=rolling_wheel_kwh / vehicle.drivetrain_efficiency,
        aerodynamic_kwh=aerodynamic_wheel_kwh / vehicle.drivetrain_efficiency,
        climbing_kwh=climbing_wheel_kwh / vehicle.drivetrain_efficiency,
        stop_start_kwh=stop_start_kwh,
        auxiliary_kwh=auxiliary_kwh,
        descent_regen_credit_kwh=descent_regen_credit_kwh,
        estimated_battery_energy_kwh=estimated,
        mean_speed_kph=mean_speed_mps * 3.6,
    )


def assess_reachability(
    vehicle: VehiclePhysicsInput,
    *,
    current_soc_percent: float,
    reserve_soc_percent: float,
    expected_energy_kwh: float,
    conservative_energy_kwh: float,
    minimum_borderline_buffer_kwh: float = 0.5,
) -> ReachabilityAssessment:
    """Classify reachability using conservative energy, not only the mean estimate."""

    if not 0 <= reserve_soc_percent < current_soc_percent <= 100:
        raise ValueError("SOC values must satisfy 0 <= reserve < current <= 100")
    if expected_energy_kwh < 0 or conservative_energy_kwh < expected_energy_kwh:
        raise ValueError("conservative energy must be nonnegative and at least the expected energy")
    if minimum_borderline_buffer_kwh < 0:
        raise ValueError("minimum borderline buffer cannot be negative")

    usable_capacity = vehicle.battery_capacity_kwh * vehicle.usable_capacity_fraction
    energy_above_reserve = usable_capacity * (
        current_soc_percent - reserve_soc_percent
    ) / 100
    safety_margin = energy_above_reserve - conservative_energy_kwh
    borderline_width = max(minimum_borderline_buffer_kwh, usable_capacity * 0.03)
    status: Literal["reachable", "borderline", "unreachable"]
    if safety_margin < 0:
        status = "unreachable"
    elif safety_margin <= borderline_width:
        status = "borderline"
    else:
        status = "reachable"

    expected_arrival_soc = current_soc_percent - expected_energy_kwh / usable_capacity * 100
    conservative_arrival_soc = (
        current_soc_percent - conservative_energy_kwh / usable_capacity * 100
    )
    return ReachabilityAssessment(
        status=status,
        expected_arrival_soc_percent=expected_arrival_soc,
        conservative_arrival_soc_percent=conservative_arrival_soc,
        energy_available_above_reserve_kwh=energy_above_reserve,
        conservative_energy_required_kwh=conservative_energy_kwh,
        safety_margin_kwh=safety_margin,
    )
