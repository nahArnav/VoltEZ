import json
from pathlib import Path

import pytest
from tests.test_demand_window import _point_partition, _suite

from voltez_ml.evaluation.demand import (
    DemandEvaluationSettings,
    _target_aligned_seasonal_naive,
    evaluate_demand_model,
)
from voltez_ml.synthetic.io import file_sha256
from voltez_ml.training.demand import DemandTrainingSettings
from voltez_ml.training.demand_window import (
    DemandWindowSettings,
    train_demand_window_model,
)


def test_target_aligned_baseline_uses_history_for_the_future_clock_slot() -> None:
    frame = _point_partition("validation", "val", rows=6)
    frame["request_lag_same_time_last_week"] = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0]
    prediction = _target_aligned_seasonal_naive(frame)

    assert prediction[0] == 20.0
    assert prediction[1] == 30.0
    assert prediction[-1] == pytest.approx(frame.iloc[-1]["request_ewm_prior"])


def test_evaluator_reports_validation_and_stress_without_opening_test(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("LOKY_MAX_CPU_COUNT", "8")
    suite_path = _suite(tmp_path, include_stress=True)
    suite = json.loads(suite_path.read_text("utf-8"))
    suite["datasets"].append(
        {
            "evaluation_role": "test",
            "tables": {"demand_features": "missing-locked-test.parquet"},
        }
    )
    suite_path.write_text(json.dumps(suite), encoding="utf-8")
    readiness_path = suite_path.parent / "training_readiness.json"
    suite["training_readiness"]["sha256"] = file_sha256(readiness_path)
    suite_path.write_text(json.dumps(suite), encoding="utf-8")

    artifact = train_demand_window_model(
        suite_path,
        tmp_path / "artifacts",
        DemandTrainingSettings(max_iter=2, maximum_training_rows=100),
        DemandWindowSettings(),
    )
    output = evaluate_demand_model(
        artifact,
        suite_path,
        tmp_path / "reports",
        DemandEvaluationSettings(
            include_stress=True,
            permutation_sample_rows=20,
            permutation_repeats=1,
        ),
    )
    report = json.loads((output / "evaluation_report.json").read_text("utf-8"))

    assert set(report["roles"]) == {"validation", "stress_test"}
    assert report["integrity"]["locked_test_touched"] is False
    assert report["roles"]["validation"]["rows"] == 77
    assert report["permutation_importance"]
    assert (output / "manifest.json").is_file()


def test_evaluation_settings_reject_invalid_permutation_controls() -> None:
    with pytest.raises(ValueError):
        DemandEvaluationSettings(permutation_sample_rows=-1)
    with pytest.raises(ValueError):
        DemandEvaluationSettings(permutation_repeats=0)
