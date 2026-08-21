import json
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from voltez_ml.synthetic.io import file_sha256
from voltez_ml.training.demand import (
    TARGET,
    DemandTrainingSettings,
    _feature_columns,
    _metrics,
    _sample_training_rows,
    _seasonal_naive,
    train_demand_model,
)


def test_demand_feature_selection_keeps_only_prediction_time_numeric_values() -> None:
    frame = pd.DataFrame(
        {
            "zone_id": ["a", "b"],
            "simulation_run_id": ["run-a", "run-b"],
            "prediction_origin": pd.date_range("2026-01-01", periods=2, tz="Asia/Kolkata"),
            "horizon_minutes": [15, 30],
            "request_lag_1": [1.0, 2.0],
            TARGET: [2, 3],
            "split": ["train", "train"],
            "run_holdout_split": ["train", "train"],
        }
    )

    assert _feature_columns(frame) == ["horizon_minutes", "request_lag_1"]


def test_seasonal_naive_uses_week_then_day_then_ewm_without_negative_counts() -> None:
    frame = pd.DataFrame(
        {
            "request_lag_same_time_last_week": [4.0, np.nan, np.nan, -3.0],
            "request_lag_same_time_yesterday": [2.0, 3.0, np.nan, np.nan],
            "request_ewm_prior": [1.0, 1.0, 2.0, 2.0],
        }
    )

    np.testing.assert_array_equal(_seasonal_naive(frame), np.array([4.0, 3.0, 2.0, 0.0]))


def test_count_metrics_and_deterministic_row_cap() -> None:
    truth = np.array([0.0, 1.0, 3.0], dtype="float64")
    prediction = np.array([0.0, 1.5, 2.5], dtype="float64")
    metrics = _metrics(truth, prediction)
    frame = pd.DataFrame({"value": range(100)})

    assert metrics["mae"] == pytest.approx(1 / 3)
    assert metrics["mean_poisson_deviance"] is not None
    first = _sample_training_rows(frame, 20, 7)
    second = _sample_training_rows(frame, 20, 7)
    pd.testing.assert_frame_equal(first, second)


@pytest.mark.parametrize(
    "values",
    [
        {"max_iter": 0},
        {"learning_rate": 0.0},
        {"max_leaf_nodes": 1},
        {"l2_regularization": -0.1},
    ],
)
def test_invalid_training_parameters_fail_before_model_fitting(values: dict[str, float]) -> None:
    with pytest.raises(ValueError):
        DemandTrainingSettings(**values)  # type: ignore[arg-type]


def _demand_partition(role: str, run_id: str, rows: int = 60) -> pd.DataFrame:
    origins = pd.date_range("2026-01-01", periods=rows, freq="15min", tz="Asia/Kolkata")
    target = np.arange(rows) % 4
    return pd.DataFrame(
        {
            "zone_id": ["zone-a"] * rows,
            "source_snapshot_id": [f"snapshot-{run_id}"] * rows,
            "simulation_run_id": [run_id] * rows,
            "prediction_origin": origins,
            "feature_cutoff": origins,
            "latest_source_time": origins - pd.to_timedelta(15, unit="m"),
            "target_time": origins + pd.to_timedelta(15, unit="m"),
            "horizon_minutes": [15] * rows,
            "request_lag_1": np.roll(target, 1).astype("float64"),
            "request_lag_same_time_last_week": [np.nan] * rows,
            "request_lag_same_time_yesterday": np.roll(target, 4).astype("float64"),
            "request_ewm_prior": pd.Series(target).ewm(span=4).mean(),
            TARGET: target,
            "split": ["train"] * rows,
            "run_holdout_split": [role] * rows,
        }
    )


def test_tiny_training_smoke_writes_a_validation_only_portable_artifact(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("LOKY_MAX_CPU_COUNT", "8")
    features_root = tmp_path / "features"
    features_root.mkdir()
    datasets = []
    for role, run_id in (("train", "train-a"), ("train", "train-b"), ("validation", "val")):
        partition = features_root / f"{run_id}.parquet"
        _demand_partition(role, run_id).to_parquet(partition, index=False)
        datasets.append(
            {
                "evaluation_role": role,
                "tables": {"demand_features": partition.name},
            }
        )
    readiness_path = features_root / "training_readiness.json"
    readiness_path.write_text(
        json.dumps(
            {
                "models": {
                    "demand": {"status": "ready", "failures": []},
                }
            }
        ),
        encoding="utf-8",
    )
    suite_path = features_root / "feature_suite_manifest.json"
    suite_path.write_text(
        json.dumps(
            {
                "training_readiness": {
                    "path": readiness_path.name,
                    "sha256": file_sha256(readiness_path),
                },
                "datasets": datasets,
            }
        ),
        encoding="utf-8",
    )

    output = train_demand_model(
        suite_path,
        tmp_path / "artifacts",
        DemandTrainingSettings(max_iter=2, maximum_training_rows=80),
    )
    report = json.loads((output / "evaluation_report.json").read_text("utf-8"))
    manifest = json.loads((output / "manifest.json").read_text("utf-8"))

    assert (output / "model.joblib").is_file()
    assert report["training_rows"] == 80
    assert report["validation_rows"] == 60
    assert report["locked_test_unlocked"] is False
    assert "locked_test" not in report
    assert file_sha256(output / "model.joblib") == manifest["artifact"]["sha256"]
    suite_reference = Path(manifest["feature_suite_manifest"])
    assert not suite_reference.is_absolute()
    assert (output / suite_reference).resolve() == suite_path.resolve()
