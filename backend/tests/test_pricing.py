from datetime import datetime
from zoneinfo import ZoneInfo

from app.services.pricing import dynamic_rate_from_signals

IST = ZoneInfo("Asia/Kolkata")


def test_dynamic_rate_is_bounded_and_explainable() -> None:
    quote = dynamic_rate_from_signals(
        base_rate=15,
        expected_demand=20,
        probability_unavailable=1.0,
        active_ports=1,
        target_time=datetime(2026, 8, 30, 18, tzinfo=IST),
    )

    assert quote.effective_rate == 19.5  # 1.30x cap, never unbounded surge
    assert quote.multiplier == 1.30
    assert quote.reason == "peak demand and limited supply"


def test_off_peak_discount_applies_before_rounding() -> None:
    quote = dynamic_rate_from_signals(
        base_rate=20,
        expected_demand=0,
        probability_unavailable=0,
        active_ports=4,
        target_time=datetime(2026, 8, 30, 1, tzinfo=IST),
    )

    assert quote.multiplier == 0.92
    assert quote.effective_rate == 18.4
    assert quote.reason == "off-peak discount"


def test_invalid_operational_signals_are_clamped_safely() -> None:
    quote = dynamic_rate_from_signals(
        base_rate=-10,
        expected_demand=-5,
        probability_unavailable=4,
        active_ports=0,
        target_time=datetime(2026, 8, 30, 12, tzinfo=IST),
    )

    assert quote.base_rate == 0.01
    assert quote.demand_pressure == 0.0
    assert quote.availability_pressure == 1.0
    assert 0.85 <= quote.multiplier <= 1.30
