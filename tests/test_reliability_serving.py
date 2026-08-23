import json
import math
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

import joblib
import numpy as np
import pytest

from voltez_ml.serving.reliability import (
    ReliabilityFeatureRequest,
    ReliabilityInputError,
    ReliabilityPredictor,
)
from voltez_ml.synthetic.io import file_sha256

NUMERIC = [
    "eta_minutes",
    "target_hour_sin",
    "target_hour_cos",
    "target_day_sin",
    "target_day_cos",
    "target_is_weekend",
]
CATEGORICAL = ["latest_status"]


class ConstantBaseModel:
    def __init__(self, probability: float) -> None:
        self.probability = probability

    def predict_proba(self, frame: object) -> np.ndarray:
        rows = len(frame)  # type: ignore[arg-type]
        positive = np.full(rows, self.probability)
        return np.column_stack([1 - positive, positive])


class IdentityCalibrator:
    def predict_proba(self, logits: np.ndarray) -> np.ndarray:
        positive = 1 / (1 + np.exp(-logits[:, 0]))
        return np.column_stack([1 - positive, positive])


def _rule(kind: str, minimum: float, maximum: float) -> dict[str, object]:
    hard_min: float | None = None
    hard_max: float | None = None
    if kind == "binary":
        hard_min, hard_max = 0.0, 1.0
    elif kind == "periodic":
        hard_min, hard_max = -1.0, 1.0
    elif kind == "nonnegative":
        hard_min = 0.0
    return {
        "kind": kind,
        "allow_missing": False,
        "train_min": minimum,
        "train_max": maximum,
        "soft_min": minimum,
        "soft_max": maximum,
        "median": (minimum + maximum) / 2,
        "hard_min": hard_min,
        "hard_max": hard_max,
        "allowed_values": [],
    }


def _predictor(
    tmp_path: Path, probability: float = 0.05
) -> tuple[ReliabilityPredictor, ReliabilityFeatureRequest]:
    artifact_dir = tmp_path / "artifact"
    artifact_dir.mkdir(parents=True)
    model_path = artifact_dir / "model.joblib"
    joblib.dump(
        {
            "base_model": ConstantBaseModel(probability),
            "calibrator": IdentityCalibrator(),
            "feature_spec": {"numeric": NUMERIC, "categorical": CATEGORICAL},
            "positive_class": "unreliable",
            "negative_class": "reliable",
            "thresholds": {
                "reliable_max_probability_unreliable": 0.1,
                "unreliable_min_probability_unreliable": 0.6,
            },
            "missing_status_policy": "unknown",
        },
        model_path,
    )
    manifest = {
        "model_id": "reliability-test-v1",
        "artifact": {"path": model_path.name, "sha256": file_sha256(model_path)},
    }
    (artifact_dir / "manifest.json").write_text(json.dumps(manifest), "utf-8")
    rules = {
        "eta_minutes": _rule("nonnegative", 15.0, 120.0),
        "target_hour_sin": _rule("periodic", -1.0, 1.0),
        "target_hour_cos": _rule("periodic", -1.0, 1.0),
        "target_day_sin": _rule("periodic", -1.0, 1.0),
        "target_day_cos": _rule("periodic", -1.0, 1.0),
        "target_is_weekend": _rule("binary", 0.0, 1.0),
        "latest_status": {
            "kind": "categorical",
            "allow_missing": False,
            "allowed_values": ["reliable", "occupied", "faulted", "unknown"],
        },
    }
    contract = {
        "schema_version": "voltez-reliability-serving-v1",
        "model_id": manifest["model_id"],
        "model_artifact_sha256": manifest["artifact"]["sha256"],
        "feature_suite_manifest_sha256": "suite-hash",
        "feature_order": NUMERIC + CATEGORICAL,
        "numeric_features": NUMERIC,
        "categorical_features": CATEGORICAL,
        "features": rules,
        "thresholds": {
            "reliable_max_probability_unreliable": 0.1,
            "unreliable_min_probability_unreliable": 0.6,
        },
        "timezone": "Asia/Kolkata",
        "training_rows": 100,
        "ood_policy": {
            "max_outside_training_range": 3,
            "max_outside_soft_range": 8,
            "unknown_category_action": "abstain",
            "missing_status_action": "abstain",
        },
        "hard_gates": ["connector compatibility", "confirmed overlapping booking"],
    }
    contract_path = tmp_path / "feature_contract.json"
    contract_path.write_text(json.dumps(contract), "utf-8")
    predictor = ReliabilityPredictor.from_artifact(artifact_dir, contract_path)

    origin = datetime(2026, 1, 5, 10, 0, tzinfo=ZoneInfo("Asia/Kolkata"))
    target = origin + timedelta(minutes=30)
    target_hour = 10.5
    target_day = 0
    request = ReliabilityFeatureRequest(
        port_id="port-a",
        prediction_origin=origin,
        target_time=target,
        features={
            "eta_minutes": 30.0,
            "target_hour_sin": math.sin(2 * math.pi * target_hour / 24),
            "target_hour_cos": math.cos(2 * math.pi * target_hour / 24),
            "target_day_sin": math.sin(2 * math.pi * target_day / 7),
            "target_day_cos": math.cos(2 * math.pi * target_day / 7),
            "target_is_weekend": 0.0,
            "latest_status": "reliable",
        },
    )
    return predictor, request


def test_calibrated_probability_and_three_state_decision(tmp_path: Path) -> None:
    reliable_predictor, request = _predictor(tmp_path / "reliable", 0.05)
    reliable = reliable_predictor.predict(request)
    assert reliable.decision == "reliable"
    assert reliable.quality == "in_domain"
    assert reliable.probability_unreliable == pytest.approx(0.05)

    unknown_predictor, unknown_request = _predictor(tmp_path / "unknown", 0.3)
    unknown = unknown_predictor.predict(unknown_request)
    assert unknown.decision == "unknown"
    assert unknown.quality == "abstained"
    assert unknown.probability_unreliable == pytest.approx(0.3)


def test_unknown_status_forces_abstention_without_probability(tmp_path: Path) -> None:
    predictor, request = _predictor(tmp_path)
    request.features["latest_status"] = "unknown"

    response = predictor.predict(request)

    assert response.decision == "unknown"
    assert response.quality == "abstained"
    assert response.probability_unreliable is None
    assert "safe abstention" in response.warnings[0]


def test_unknown_category_and_large_distribution_shift_abstain(tmp_path: Path) -> None:
    predictor, request = _predictor(tmp_path)
    request.features["latest_status"] = "new_status_from_future_provider"

    response = predictor.predict(request)

    assert response.decision == "unknown"
    assert response.probability_unreliable is None


def test_schema_and_timestamp_disagreement_are_rejected(tmp_path: Path) -> None:
    predictor, request = _predictor(tmp_path)
    bad_time = request.model_copy(deep=True)
    bad_time.features["eta_minutes"] = 90.0
    missing = request.model_copy(deep=True)
    missing.features.pop("latest_status")

    with pytest.raises(ReliabilityInputError, match="timestamps"):
        predictor.predict(bad_time)
    with pytest.raises(ReliabilityInputError, match="schema mismatch"):
        predictor.predict(missing)


def test_batch_matches_single_prediction(tmp_path: Path) -> None:
    predictor, request = _predictor(tmp_path)
    single = predictor.predict(request)
    batch = predictor.predict_batch([request, request])

    assert batch == [single, single]
