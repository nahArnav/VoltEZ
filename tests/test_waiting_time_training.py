import json
import warnings
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import pytest

from voltez_ml.synthetic.io import file_sha256, write_manifest
from voltez_ml.training.waiting_time import (
    HurdleWaitingTimeRegressor,
    WaitingTimeTrainingSettings,
    train_hurdle_waiting_time_model,
    TARGET
)

class _OccurrenceStub:
    classes_ = np.array([0, 1])

    def predict_proba(self, features: np.ndarray) -> np.ndarray:
        positive = np.array([0.2, 0.8], dtype="float64")[: len(features)]
        return np.column_stack([1.0 - positive, positive])


class _PositiveCountStub:
    def predict(self, features: np.ndarray) -> np.ndarray:
        return np.array([0.5, 3.0], dtype="float64")[: len(features)]


def test_hurdle_prediction_multiplies_probability_by_positive_mean() -> None:
    model = HurdleWaitingTimeRegressor(numeric_features=["f1"], categorical_features=[])
    model.occurrence_model_ = _OccurrenceStub()
    model.positive_count_model_ = _PositiveCountStub()
    model.n_features_in_ = 1
    
    # Mock _transform instead of directly passing arrays to models
    import pandas as pd
    def _mock_transform(frame):
        return np.array([[1.0], [2.0]], dtype="float32")
    model._transform = _mock_transform
    
    features = pd.DataFrame({"f1": [1.0, 2.0]})

    np.testing.assert_allclose(model.predict_nonzero_probability(features), [0.2, 0.8])
    np.testing.assert_allclose(model.predict_positive_mean(features), [0.5, 3.0])
    np.testing.assert_allclose(model.predict(features), [0.1, 2.4])


def _suite(tmp_path: Path) -> Path:
    data_root = tmp_path / "data"
    data_root.mkdir()
    entries = []
    definitions = [
        ("train", "train-a", 1),
        ("train", "train-b", 2),
        ("validation", "validation-a", 3),
        ("stress_test", "stress-a", 4),
    ]
    for role, world, seed in definitions:
        path = data_root / f"{world}.parquet"
        rng = np.random.default_rng(seed)
        rows = 180
        pd.DataFrame({
            "simulation_run_id": world,
            "run_holdout_split": role,
            TARGET: np.resize(np.array([0.0, 10.0, 0.0, 25.0], dtype="float64"), rows),
            "eta_minutes": rng.choice([15.0, 30.0, 60.0, 120.0], size=rows),
            "target_hour_sin": rng.uniform(-1, 1, size=rows),
            "active_session_count": rng.binomial(1, 0.18, size=rows),
            "status_expired": rng.binomial(1, 0.65, size=rows),
            "latest_status": rng.choice(["available", "occupied", "faulted"], size=rows),
            "reliability_cold_start": rng.binomial(1, 0.1, size=rows),
            "connector_code": rng.choice(["ccs2", "type_2"], size=rows),
        }).to_parquet(path, index=False)
        entries.append(
            {
                "evaluation_role": role,
                "run_id": world,
                "tables": {"waiting_time_features_labeled": str(path)},
            }
        )
    readiness_path = tmp_path / "training_readiness.json"
    write_manifest({"models": {"waiting_time": {"status": "ready", "failures": []}}}, readiness_path)
    manifest_path = tmp_path / "feature_suite_manifest.json"
    write_manifest(
        {
            "training_readiness": {"path": readiness_path.name, "sha256": file_sha256(readiness_path)},
            "datasets": entries,
        },
        manifest_path,
    )
    return manifest_path


def test_hurdle_training_writes_reusable_locked_test_safe_artifact(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("LOKY_MAX_CPU_COUNT", "8")
    suite_path = _suite(tmp_path)
    artifact = train_hurdle_waiting_time_model(
        suite_path,
        tmp_path / "artifacts",
        WaitingTimeTrainingSettings(
            classifier_max_iter=2,
            count_max_iter=2,
            maximum_training_rows=100,
        ),
    )
    report = json.loads((artifact / "evaluation_report.json").read_text("utf-8"))
    manifest = json.loads((artifact / "manifest.json").read_text("utf-8"))
    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore",
            message="Setting the shape on a NumPy array has been deprecated.*",
            category=DeprecationWarning,
        )
        payload = joblib.load(artifact / "model.joblib")

    assert report["model"] == "waiting_time_hurdle"
    assert report["training_rows"] == 100
    assert report["locked_test_unlocked"] is False
    assert payload["prediction_contract"]["expected_wait"] == "predict"
    assert file_sha256(artifact / "model.joblib") == manifest["artifact"]["sha256"]

def test_hurdle_settings_reject_invalid_values() -> None:
    with pytest.raises(ValueError):
        WaitingTimeTrainingSettings(classifier_max_iter=0)
