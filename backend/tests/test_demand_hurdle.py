import json
import warnings
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import pytest
from tests.test_demand_window import _suite

from voltez_ml.evaluation.demand import DemandEvaluationSettings, evaluate_demand_model
from voltez_ml.synthetic.io import file_sha256
from voltez_ml.training.demand import TARGET
from voltez_ml.training.demand_hurdle import (
    HurdleDemandRegressor,
    HurdleTrainingSettings,
    train_hurdle_demand_window_model,
)
from voltez_ml.training.demand_window import DemandWindowSettings


class _OccurrenceStub:
    classes_ = np.array([0, 1])

    def predict_proba(self, features: np.ndarray) -> np.ndarray:
        positive = np.array([0.2, 0.8], dtype="float64")[: len(features)]
        return np.column_stack([1.0 - positive, positive])


class _PositiveCountStub:
    def predict(self, features: np.ndarray) -> np.ndarray:
        return np.array([0.5, 3.0], dtype="float64")[: len(features)]


def test_hurdle_prediction_multiplies_probability_by_positive_mean() -> None:
    model = HurdleDemandRegressor()
    model.occurrence_model_ = _OccurrenceStub()
    model.positive_count_model_ = _PositiveCountStub()
    model.n_features_in_ = 1
    features = np.array([[1.0], [2.0]], dtype="float32")

    np.testing.assert_allclose(model.predict_nonzero_probability(features), [0.2, 0.8])
    np.testing.assert_allclose(model.predict_positive_mean(features), [1.0, 3.0])
    np.testing.assert_allclose(model.predict(features), [0.2, 2.4])


@pytest.mark.parametrize(
    "target",
    [
        np.array([0.0, 0.0, 0.0]),
        np.array([1.0, 2.0, 3.0]),
        np.array([0.0, -1.0, 2.0]),
        np.array([0.0, 1.5, 2.0]),
    ],
)
def test_hurdle_rejects_invalid_training_targets(target: np.ndarray) -> None:
    with pytest.raises(ValueError):
        HurdleDemandRegressor(classifier_max_iter=2, count_max_iter=2).fit(
            np.arange(3, dtype="float32").reshape(-1, 1), target
        )


def test_hurdle_training_writes_reusable_locked_test_safe_artifact(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("LOKY_MAX_CPU_COUNT", "8")
    suite_path = _suite(tmp_path, include_stress=True)
    suite = json.loads(suite_path.read_text("utf-8"))
    for dataset in suite["datasets"]:
        feature_path = suite_path.parent / dataset["tables"]["demand_features"]
        frame = pd.read_parquet(feature_path)
        frame[TARGET] = np.resize(np.repeat(np.array([0, 1, 0, 2], dtype="int64"), 20), len(frame))
        frame.to_parquet(feature_path, index=False)
    suite["datasets"].append(
        {
            "evaluation_role": "test",
            "tables": {"demand_features": "missing-locked-test.parquet"},
        }
    )
    suite_path.write_text(json.dumps(suite), encoding="utf-8")

    artifact = train_hurdle_demand_window_model(
        suite_path,
        tmp_path / "artifacts",
        HurdleTrainingSettings(
            classifier_max_iter=2,
            count_max_iter=2,
            maximum_training_rows=100,
        ),
        DemandWindowSettings(),
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

    assert report["model"] == "demand_forecasting_hurdle_rolling_window"
    assert report["training_rows"] == 100
    assert report["locked_test_unlocked"] is False
    assert "locked_test" not in report
    assert report["validation"]["formula_integrity_max_absolute_error"] == 0.0
    assert payload["prediction_contract"]["expected_demand"] == "predict"
    assert file_sha256(artifact / "model.joblib") == manifest["artifact"]["sha256"]

    evaluation = evaluate_demand_model(
        artifact,
        suite_path,
        tmp_path / "reports",
        DemandEvaluationSettings(
            include_stress=True,
            permutation_sample_rows=20,
            permutation_repeats=1,
        ),
    )
    evaluation_report = json.loads((evaluation / "evaluation_report.json").read_text("utf-8"))
    assert set(evaluation_report["roles"]) == {"validation", "stress_test"}
    assert evaluation_report["integrity"]["locked_test_touched"] is False
    assert "hurdle_stages" in evaluation_report["roles"]["validation"]


def test_hurdle_settings_reject_invalid_values() -> None:
    with pytest.raises(ValueError):
        HurdleTrainingSettings(classifier_max_iter=0)
    with pytest.raises(ValueError):
        HurdleTrainingSettings(count_learning_rate=0)
    with pytest.raises(ValueError):
        HurdleTrainingSettings(count_max_leaf_nodes=1)
    with pytest.raises(ValueError):
        HurdleTrainingSettings(classifier_l2_regularization=-0.1)
    with pytest.raises(ValueError):
        HurdleTrainingSettings(maximum_training_rows=0)
