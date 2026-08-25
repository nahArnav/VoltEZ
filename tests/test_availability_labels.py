from datetime import timedelta
from typing import Any

import pandas as pd
import pytest

from voltez_ml.synthetic.events import _verified_session_availability

TARGET = pd.Timestamp("2026-02-10 18:00:00", tz="Asia/Kolkata")


def _started_session(service_ready_delay: timedelta) -> dict[str, Any]:
    service_ready_at = TARGET + service_ready_delay
    return {
        "arrived_at": TARGET + timedelta(minutes=3),
        "service_ready_at": service_ready_at,
        "start_at": service_ready_at + timedelta(minutes=2),
        "check_in_at": TARGET,
        "status": "completed",
        "failure_reason": None,
    }


@pytest.mark.parametrize("delay_minutes", [0, 10])
def test_verified_service_ready_at_or_inside_tolerance_is_available(
    delay_minutes: int,
) -> None:
    outcome = _verified_session_availability(
        TARGET,
        _started_session(timedelta(minutes=delay_minutes)),
        tolerance_minutes=10,
    )

    assert outcome is not None
    assert outcome[0] == "available"
    assert outcome[1] == "verified_service_ready_within_tolerance"


def test_verified_service_ready_after_tolerance_is_unavailable() -> None:
    outcome = _verified_session_availability(
        TARGET,
        _started_session(timedelta(minutes=10, seconds=1)),
        tolerance_minutes=10,
    )

    assert outcome is not None
    assert outcome[0] == "unavailable"
    assert outcome[1] == "verified_service_ready_after_tolerance"


def test_verified_failure_before_service_is_unavailable() -> None:
    outcome = _verified_session_availability(
        TARGET,
        {
            "arrived_at": TARGET + timedelta(minutes=3),
            "service_ready_at": pd.NaT,
            "start_at": pd.NaT,
            "check_in_at": TARGET + timedelta(minutes=3),
            "status": "failed",
            "failure_reason": "charger_fault",
        },
        tolerance_minutes=10,
    )

    assert outcome is not None
    assert outcome[0] == "unavailable"
    assert outcome[1] == "verified_check_in_failure"


def test_mid_session_fault_does_not_rewrite_arrival_availability() -> None:
    session = _started_session(timedelta(minutes=4))
    session["status"] = "failed"
    session["failure_reason"] = "charger_fault_mid_session"

    outcome = _verified_session_availability(
        TARGET,
        session,
        tolerance_minutes=10,
    )

    assert outcome is not None
    assert outcome[0] == "available"


def test_late_driver_cannot_create_a_port_availability_label() -> None:
    session = _started_session(timedelta(minutes=12))
    session["arrived_at"] = TARGET + timedelta(minutes=11)

    outcome = _verified_session_availability(
        TARGET,
        session,
        tolerance_minutes=10,
    )

    assert outcome is None
