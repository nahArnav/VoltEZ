from datetime import datetime

import pytest
from pydantic import ValidationError

from voltez_ml.serving.waiting_time import (
    WaitingTimeFeatureRequest,
    WaitingTimeOODPolicy,
)


def test_waiting_time_feature_request_validation() -> None:
    # Missing timezone
    with pytest.raises(ValidationError):
        WaitingTimeFeatureRequest(
            port_id="port-1",
            prediction_origin=datetime(2026, 1, 1, 12, 0),
            target_time=datetime(2026, 1, 1, 13, 0),
            features={"eta_minutes": 15.0},
        )


def test_waiting_time_ood_policy() -> None:
    policy = WaitingTimeOODPolicy(max_outside_training_range=5, max_outside_soft_range=10)
    assert policy.action == "zero_wait_fallback"
