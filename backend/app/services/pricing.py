"""Bounded, explainable dynamic pricing used by live booking flows.

The station owner controls the base tariff.  VoltEZ only applies a small,
transparent multiplier for peak/off-peak time and observed demand pressure;
the multiplier is clamped so pricing can never become an unbounded surge.
"""

from dataclasses import dataclass
from datetime import datetime
from zoneinfo import ZoneInfo

_IST = ZoneInfo("Asia/Kolkata")
_MIN_MULTIPLIER = 0.85
_MAX_MULTIPLIER = 1.30


@dataclass(frozen=True)
class DynamicRate:
    base_rate: float
    effective_rate: float
    multiplier: float
    demand_pressure: float
    availability_pressure: float
    reason: str


def dynamic_rate_from_signals(
    *,
    base_rate: float,
    expected_demand: float,
    probability_unavailable: float,
    active_ports: int,
    target_time: datetime,
) -> DynamicRate:
    """Calculate a bounded INR/kWh rate from explicit operational signals.

    ``expected_demand`` may come from Model 1 or a conservative booking
    count when a model is unavailable.  ``probability_unavailable`` is the
    calibrated Model 2 output when available.  Both signals are normalized
    by active ports so a large station is not charged like a single-port site.
    """
    safe_base = max(float(base_rate), 0.01)
    ports = max(int(active_ports), 1)
    demand_pressure = min(max(float(expected_demand) / ports, 0.0), 3.0)
    availability_pressure = min(max(float(probability_unavailable), 0.0), 1.0)

    local = target_time.astimezone(_IST)
    hour = local.hour
    is_peak = 8 <= hour < 11 or 17 <= hour < 22
    is_off_peak = hour < 6 or hour >= 23

    multiplier = 1.0 + 0.10 * demand_pressure + 0.12 * availability_pressure
    if is_peak:
        multiplier += 0.07
    elif is_off_peak:
        multiplier -= 0.08
    multiplier = min(max(multiplier, _MIN_MULTIPLIER), _MAX_MULTIPLIER)

    if is_peak and (demand_pressure > 0.75 or availability_pressure > 0.35):
        reason = "peak demand and limited supply"
    elif is_off_peak:
        reason = "off-peak discount"
    elif demand_pressure > 0.75:
        reason = "elevated local demand"
    else:
        reason = "balanced local demand"

    return DynamicRate(
        base_rate=round(safe_base, 2),
        effective_rate=round(safe_base * multiplier, 2),
        multiplier=round(multiplier, 4),
        demand_pressure=round(demand_pressure, 4),
        availability_pressure=round(availability_pressure, 4),
        reason=reason,
    )
