import json
import warnings
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import pytest

from voltez_ml.synthetic.io import file_sha256
from voltez_ml.training.demand import TARGET, DemandTrainingSettings, _feature_columns
from voltez_ml.training.demand_window import (
    WINDOW_BASELINE,
    DemandWindowSettings,
    build_rolling_demand_window,
    train_demand_window_model,
)


def _point_partition(role: str, run_id: str, rows: int = 80) -> pd.DataFrame:
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
            "request_lag_same_time_last_week": np.roll(target, 8).astype("float64"),
            "request_lag_same_time_yesterday": np.roll(target, 4).astype("float64"),
            "request_ewm_prior": pd.Series(target).ewm(span=4).mean(),
            "target_hour_sin": np.sin(2 * np.pi * origins.hour / 24),
            "target_hour_cos": np.cos(2 * np.pi * origins.hour / 24),
            "target_day_sin": np.sin(2 * np.pi * origins.dayofweek / 7),
            "target_day_cos": np.cos(2 * np.pi * origins.dayofweek / 7),
            "target_is_weekend": (origins.dayofweek >= 5).astype("int8"),
            TARGET: target,
            "split": ["train"] * rows,
            "run_holdout_split": [role] * rows,
        }
    )


def _suite(tmp_path: Path, include_stress: bool = False) -> Path:
    features_root = tmp_path / "features"
    features_root.mkdir()
    roles = [("train", "train-a"), ("train", "train-b"), ("validation", "val")]
    if include_stress:
        roles.append(("stress_test", "stress"))
    datasets = []
    for role, run_id in roles:
        path = features_root / f"{run_id}.parquet"
        _point_partition(role, run_id).to_parquet(path, index=False)
        datasets.append({"evaluation_role": role, "tables": {"demand_features": path.name}})
    readiness_path = features_root / "training_readiness.json"
    readiness_path.write_text(
        json.dumps({"models": {"demand": {"status": "ready", "failures": []}}}),
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
    return suite_path


def test_rolling_window_sums_future_labels_but_keeps_only_origin_features() -> None:
    frame = _point_partition("train", "run-a", rows=7)
    frame[TARGET] = np.arange(1, 8)
    frame["request_lag_1"] = [10.0, 999.0, 30.0, 40.0, 50.0, 60.0, 70.0]
    frame["request_lag_same_time_yesterday"] = np.arange(1, 8) * 10.0
    frame["request_lag_same_time_last_week"] = np.arange(1, 8) * 100.0

    result = build_rolling_demand_window(frame, DemandWindowSettings())

    assert len(result) == 4
    assert result.loc[0, TARGET] == 1 + 2 + 3 + 4
    assert result.loc[1, TARGET] == 2 + 3 + 4 + 5
    assert result.loc[0, "request_lag_1"] == 10.0
    assert result.loc[0, "request_sum_same_window_last_week"] == 200 + 300 + 400 + 500
    assert result.loc[0, WINDOW_BASELINE] == 200 + 300 + 400 + 500
    assert result.loc[0, "target_window_minutes"] == 60
    assert result.loc[0, "forecast_lead_minutes"] == 15
    assert bool((result["latest_source_time"] < result["prediction_origin"]).all())
    features = _feature_columns(result)
    assert WINDOW_BASELINE not in features
    assert "request_sum_same_window_last_week" in features


@pytest.mark.parametrize(
    "values",
    [
        {"window_minutes": 0},
        {"window_minutes": 50},
        {"forecast_lead_minutes": 0},
        {"forecast_lead_minutes": 20},
        {"window_minutes": 1440},
    ],
)
def test_invalid_window_definitions_are_rejected(values: dict[str, int]) -> None:
    with pytest.raises(ValueError):
        DemandWindowSettings(**values)


def test_window_training_writes_a_hashed_validation_only_artifact(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("LOKY_MAX_CPU_COUNT", "8")
    suite_path = _suite(tmp_path)
    output = train_demand_window_model(
        suite_path,
        tmp_path / "artifacts",
        DemandTrainingSettings(max_iter=2, maximum_training_rows=100),
        DemandWindowSettings(),
    )
    report = json.loads((output / "evaluation_report.json").read_text("utf-8"))
    manifest = json.loads((output / "manifest.json").read_text("utf-8"))
    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore",
            message="Setting the shape on a NumPy array has been deprecated.*",
            category=DeprecationWarning,
        )
        payload = joblib.load(output / "model.joblib")

    assert report["model"] == "demand_forecasting_rolling_window"
    assert report["training_rows"] == 100
    assert report["validation_rows"] == 77
    assert report["locked_test_unlocked"] is False
    assert "locked_test" not in report
    assert payload["target_spec"]["window_minutes"] == 60
    assert file_sha256(output / "model.joblib") == manifest["artifact"]["sha256"]
    reference = Path(manifest["feature_suite_manifest"])
    assert not reference.is_absolute()
    assert (output / reference).resolve() == suite_path.resolve()
