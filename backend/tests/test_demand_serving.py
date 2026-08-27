import json
import math
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import joblib
import numpy as np
import pytest
from pydantic import ValidationError
from sklearn.dummy import DummyRegressor

from voltez_ml.serving.demand import (
    DemandFeatureContract,
    DemandFeatureRequest,
    DemandInputError,
    DemandPredictor,
)
from voltez_ml.synthetic.io import file_sha256

FEATURES = [
    "request_lag_1",
    "request_ewm_prior",
    "request_sum_same_window_yesterday",
    "request_sum_same_window_last_week",
    "missing_same_window_yesterday",
    "missing_same_window_last_week",
    "target_hour_sin",
    "target_hour_cos",
    "target_day_sin",
    "target_day_cos",
    "target_is_weekend",
    "zone_type_office",
]


def _rule(kind: str, minimum: float, maximum: float) -> dict[str, object]:
    hard_min: float | None = None
    hard_max: float | None = None
    if kind == "nonnegative":
        hard_min = 0.0
    elif kind == "binary":
        hard_min, hard_max = 0.0, 1.0
    elif kind == "periodic":
        hard_min, hard_max = -1.0, 1.0
    return {
        "kind": kind,
        "train_min": minimum,
        "train_max": maximum,
        "soft_min": minimum,
        "soft_max": maximum,
        "median": (minimum + maximum) / 2,
        "missing_rate": 0.0,
        "allow_missing": False,
        "hard_min": hard_min,
        "hard_max": hard_max,
    }


def _predictor(tmp_path: Path) -> tuple[DemandPredictor, DemandFeatureRequest]:
    artifact_dir = tmp_path / "artifact"
    artifact_dir.mkdir()
    model = DummyRegressor(strategy="constant", constant=1.75).fit(
        np.zeros((2, len(FEATURES))), [1.0, 2.0]
    )
    model_path = artifact_dir / "model.joblib"
    joblib.dump({"model": model, "features": FEATURES}, model_path)
    manifest = {
        "model_id": "demand-test-v1",
        "artifact": {"path": model_path.name, "sha256": file_sha256(model_path)},
    }
    (artifact_dir / "manifest.json").write_text(json.dumps(manifest), "utf-8")

    rules = {
        name: _rule(
            "binary"
            if name.startswith("missing_") or name in {"target_is_weekend", "zone_type_office"}
            else "periodic"
            if name.startswith("target_")
            else "nonnegative",
            -1.0 if name.startswith("target_") and name != "target_is_weekend" else 0.0,
            1.0
            if name.startswith("target_") or name.startswith("missing_") or name.startswith("zone_")
            else 5.0,
        )
        for name in FEATURES
    }
    contract = {
        "schema_version": "voltez-demand-serving-v1",
        "model_id": manifest["model_id"],
        "model_artifact_sha256": manifest["artifact"]["sha256"],
        "feature_suite_manifest_sha256": "suite-hash",
        "feature_order": FEATURES,
        "features": rules,
        "target_spec": {
            "kind": "rolling_sum",
            "window_minutes": 60,
            "forecast_lead_minutes": 15,
            "bucket_minutes": 15,
        },
        "timezone": "Asia/Kolkata",
        "training_rows": 100,
        "target_distribution": {
            "min": 0.0,
            "max": 10.0,
            "mean": 1.0,
            "zero_rate": 0.5,
            "p99": 6.0,
        },
        "ood_policy": {
            "max_outside_training_range": 0,
            "max_outside_soft_range": 0,
            "action": "seasonal_fallback",
        },
        "fallback_feature_order": sorted(
            {
                "request_sum_same_window_last_week",
                "request_sum_same_window_yesterday",
                "missing_same_window_last_week",
                "missing_same_window_yesterday",
                "request_ewm_prior",
            }
        ),
    }
    contract_path = tmp_path / "contract.json"
    contract_path.write_text(json.dumps(contract), "utf-8")
    predictor = DemandPredictor.from_artifact(artifact_dir, contract_path)

    origin = datetime(2026, 1, 5, 10, 0, tzinfo=ZoneInfo("Asia/Kolkata"))
    target_hour = 10.25
    target_day = 0
    values = {
        "request_lag_1": 1.0,
        "request_ewm_prior": 0.5,
        "request_sum_same_window_yesterday": 2.0,
        "request_sum_same_window_last_week": 4.0,
        "missing_same_window_yesterday": 0.0,
        "missing_same_window_last_week": 0.0,
        "target_hour_sin": math.sin(2 * math.pi * target_hour / 24),
        "target_hour_cos": math.cos(2 * math.pi * target_hour / 24),
        "target_day_sin": math.sin(2 * math.pi * target_day / 7),
        "target_day_cos": math.cos(2 * math.pi * target_day / 7),
        "target_is_weekend": 0.0,
        "zone_type_office": 1.0,
    }
    request = DemandFeatureRequest(zone_id="zone-a", prediction_origin=origin, features=values)
    return predictor, request


def test_valid_prediction_matches_model_and_batch_is_consistent(tmp_path: Path) -> None:
    predictor, request = _predictor(tmp_path)
    single = predictor.predict(request)
    batch = predictor.predict_batch([request, request])

    assert single.expected_requests == 1.75
    assert single.quality == "in_domain"
    assert batch[0] == single
    assert batch[1] == single
    assert single.target_window_end > single.target_window_start


def test_semantically_invalid_and_schema_drift_inputs_are_rejected(tmp_path: Path) -> None:
    predictor, request = _predictor(tmp_path)
    negative = request.model_copy(deep=True)
    negative.features["request_lag_1"] = -1.0
    calendar = request.model_copy(deep=True)
    calendar.features["target_hour_sin"] = 0.0
    zone = request.model_copy(deep=True)
    zone.features["zone_type_office"] = 0.0
    missing = request.model_copy(deep=True)
    missing.features.pop("request_lag_1")

    with pytest.raises(DemandInputError):
        predictor.predict(negative)
    with pytest.raises(DemandInputError):
        predictor.predict(calendar)
    with pytest.raises(DemandInputError):
        predictor.predict(zone)
    with pytest.raises(DemandInputError):
        predictor.predict(missing)


def test_valid_but_out_of_distribution_input_uses_seasonal_fallback(
    tmp_path: Path,
) -> None:
    predictor, request = _predictor(tmp_path)
    shifted = request.model_copy(deep=True)
    shifted.features["request_lag_1"] = 100.0

    response = predictor.predict(shifted)

    assert response.quality == "fallback"
    assert response.expected_requests == 4.0
    assert response.used_fallback is True
    assert response.outside_training_range == ["request_lag_1"]


def test_request_requires_timezone_and_contract_rejects_unknown_fields() -> None:
    with pytest.raises(ValidationError):
        DemandFeatureRequest(
            zone_id="zone-a",
            prediction_origin=datetime(2026, 1, 1, 10, 0),
            features={},
        )
    with pytest.raises(ValidationError):
        DemandFeatureContract.model_validate(
            {
                "schema_version": "voltez-demand-serving-v1",
                "unexpected": True,
            }
        )
