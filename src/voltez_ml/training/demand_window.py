"""Causal rolling-window demand targets and Model 1 aggregation experiments."""

from __future__ import annotations

import hashlib
import json
import subprocess
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import joblib  # type: ignore[import-untyped]
import numpy as np
import pandas as pd
from sklearn.ensemble import HistGradientBoostingRegressor  # type: ignore[import-untyped]

from voltez_ml.synthetic.io import file_sha256, write_manifest
from voltez_ml.training.demand import (
    TARGET,
    DemandTrainingSettings,
    _feature_columns,
    _load_role,
    _load_suite,
    _metrics,
    _portable_artifact_reference,
    _sample_training_rows,
)

WINDOW_BASELINE = "seasonal_naive_window"


@dataclass(frozen=True)
class DemandWindowSettings:
    """Definition of the future count window seen by the application."""

    window_minutes: int = 60
    forecast_lead_minutes: int = 15
    bucket_minutes: int = 15

    def __post_init__(self) -> None:
        if self.window_minutes <= 0 or self.bucket_minutes <= 0:
            raise ValueError("window and bucket minutes must be positive")
        if self.forecast_lead_minutes < self.bucket_minutes:
            raise ValueError("forecast lead must be at least one complete bucket")
        if self.window_minutes % self.bucket_minutes:
            raise ValueError("window minutes must be divisible by bucket minutes")
        if self.forecast_lead_minutes % self.bucket_minutes:
            raise ValueError("forecast lead must align to the bucket size")
        furthest_target_minutes = (
            self.forecast_lead_minutes + self.window_minutes - self.bucket_minutes
        )
        if furthest_target_minutes >= 24 * 60:
            raise ValueError(
                "rolling window must stay within one day so target-aligned yesterday "
                "values are historical at the origin"
            )


def build_rolling_demand_window(
    frame: pd.DataFrame,
    settings: DemandWindowSettings,
) -> pd.DataFrame:
    """Sum future point targets while retaining only the feature row at the origin."""

    required = {
        "simulation_run_id",
        "zone_id",
        "prediction_origin",
        "target_time",
        "horizon_minutes",
        "request_lag_same_time_yesterday",
        "request_lag_same_time_last_week",
        "request_ewm_prior",
        TARGET,
    }
    missing = required - set(frame.columns)
    if missing:
        raise ValueError(f"demand window input is missing columns: {sorted(missing)}")

    base = frame[frame["horizon_minutes"] == settings.forecast_lead_minutes].copy()
    if base.empty:
        raise ValueError("no rows match the rolling-window forecast lead")
    keys = ["simulation_run_id", "zone_id"]
    base = base.sort_values([*keys, "prediction_origin"], kind="mergesort").reset_index(drop=True)
    group = base.groupby(keys, sort=False)
    bucket_count = settings.window_minutes // settings.bucket_minutes
    target_sum = pd.Series(0.0, index=base.index, dtype="float64")
    baseline_sum = pd.Series(0.0, index=base.index, dtype="float64")
    yesterday_sum = pd.Series(0.0, index=base.index, dtype="float64")
    last_week_sum = pd.Series(0.0, index=base.index, dtype="float64")
    yesterday_complete = pd.Series(True, index=base.index, dtype="bool")
    last_week_complete = pd.Series(True, index=base.index, dtype="bool")
    complete = pd.Series(True, index=base.index, dtype="bool")
    fallback = base["request_ewm_prior"].fillna(0.0).clip(lower=0.0)
    target_start = pd.to_datetime(base["target_time"])
    lead_buckets = settings.forecast_lead_minutes // settings.bucket_minutes

    for offset in range(bucket_count):
        target = group[TARGET].shift(-offset)
        shifted_time = pd.to_datetime(group["target_time"].shift(-offset))
        expected_time = target_start + pd.to_timedelta(
            offset * settings.bucket_minutes, unit="m"
        )
        complete &= target.notna() & shifted_time.eq(expected_time)
        target_sum += target.fillna(0.0)

        history_offset = offset + lead_buckets
        last_week = group["request_lag_same_time_last_week"].shift(-history_offset)
        yesterday = group["request_lag_same_time_yesterday"].shift(-history_offset)
        # Yesterday/week values for every future bucket already occurred before the origin.
        # The EWM fallback stays anchored to the origin so no future rolling state leaks in.
        baseline_sum += last_week.fillna(yesterday).fillna(fallback).clip(lower=0.0)
        yesterday_sum += yesterday.fillna(0.0).clip(lower=0.0)
        last_week_sum += last_week.fillna(0.0).clip(lower=0.0)
        yesterday_complete &= yesterday.notna()
        last_week_complete &= last_week.notna()

    result = base.loc[complete].copy()
    result[TARGET] = target_sum.loc[complete].round().astype("int64")
    result[WINDOW_BASELINE] = baseline_sum.loc[complete].astype("float64")
    result["request_sum_same_window_yesterday"] = yesterday_sum.loc[complete].astype(
        "float64"
    )
    result["request_sum_same_window_last_week"] = last_week_sum.loc[complete].astype(
        "float64"
    )
    result["missing_same_window_yesterday"] = (~yesterday_complete.loc[complete]).astype(
        "int8"
    )
    result["missing_same_window_last_week"] = (~last_week_complete.loc[complete]).astype(
        "int8"
    )
    result["forecast_lead_minutes"] = settings.forecast_lead_minutes
    result["target_window_minutes"] = settings.window_minutes
    result["target_window_start"] = pd.to_datetime(result["target_time"])
    result["target_window_end"] = result["target_window_start"] + pd.to_timedelta(
        settings.window_minutes, unit="m"
    )
    if result.duplicated([*keys, "prediction_origin"]).any():
        raise ValueError("rolling demand windows are not unique at the prediction origin")
    if bool((pd.to_datetime(result["latest_source_time"]) >= result["prediction_origin"]).any()):
        raise ValueError("rolling demand features include evidence at or after the origin")
    return result.reset_index(drop=True)


def _git_state(project_root: Path) -> dict[str, str | bool | None]:
    try:
        commit = subprocess.run(
            ["/usr/bin/git", "rev-parse", "HEAD"],
            cwd=project_root,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        dirty = bool(
            subprocess.run(
                ["/usr/bin/git", "status", "--porcelain"],
                cwd=project_root,
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
        )
        return {"commit": commit, "dirty": dirty}
    except (OSError, subprocess.CalledProcessError):
        return {"commit": None, "dirty": None}


def _window_role(
    suite: dict[str, Any], role: str, settings: DemandWindowSettings
) -> pd.DataFrame:
    return build_rolling_demand_window(_load_role(suite, role), settings)


def train_demand_window_model(
    suite_manifest_path: Path,
    output_root: Path,
    model_settings: DemandTrainingSettings,
    window_settings: DemandWindowSettings,
    unlock_test: bool = False,
) -> Path:
    """Train a count model for one causal rolling future-demand window."""

    suite, readiness = _load_suite(suite_manifest_path)
    train = _sample_training_rows(
        _window_role(suite, "train", window_settings),
        model_settings.maximum_training_rows,
        model_settings.random_seed,
    )
    validation = _window_role(suite, "validation", window_settings)
    features = _feature_columns(train)
    missing_validation = set(features) - set(validation.columns)
    if missing_validation:
        raise ValueError(
            f"validation partition is missing features: {sorted(missing_validation)}"
        )

    model = HistGradientBoostingRegressor(
        loss="poisson",
        learning_rate=model_settings.learning_rate,
        max_iter=model_settings.max_iter,
        max_leaf_nodes=model_settings.max_leaf_nodes,
        l2_regularization=model_settings.l2_regularization,
        early_stopping=False,
        random_state=model_settings.random_seed,
    )
    train_x = train[features].astype("float32")
    train_y = train[TARGET].to_numpy(dtype="float64")
    validation_y = validation[TARGET].to_numpy(dtype="float64")
    model.fit(train_x, train_y)
    validation_prediction = np.clip(
        model.predict(validation[features].astype("float32")), 0.0, None
    )
    report: dict[str, Any] = {
        "model": "demand_forecasting_rolling_window",
        "algorithm": "HistGradientBoostingRegressor(loss=poisson)",
        "device": "cpu",
        "hardware_note": "scikit-learn histogram boosting uses the Apple M4 CPU, not MPS",
        "training_rows": len(train),
        "validation_rows": len(validation),
        "feature_count": len(features),
        "features": features,
        "model_settings": asdict(model_settings),
        "target_spec": {"kind": "rolling_sum", **asdict(window_settings)},
        "validation": {
            "seasonal_naive": _metrics(
                validation_y,
                validation[WINDOW_BASELINE].to_numpy(dtype="float64"),
            ),
            "poisson_hist_gradient_boosting": _metrics(
                validation_y, validation_prediction
            ),
        },
        "locked_test_unlocked": unlock_test,
        "data_readiness": readiness["models"]["demand"],
    }
    if unlock_test:
        locked_test = _window_role(suite, "test", window_settings)
        test_y = locked_test[TARGET].to_numpy(dtype="float64")
        report["locked_test"] = {
            "seasonal_naive": _metrics(
                test_y, locked_test[WINDOW_BASELINE].to_numpy(dtype="float64")
            ),
            "poisson_hist_gradient_boosting": _metrics(
                test_y,
                np.clip(
                    model.predict(locked_test[features].astype("float32")), 0.0, None
                ),
            ),
        }

    project_root = Path.cwd().resolve()
    code_state = _git_state(project_root)
    trainer_source_hash = file_sha256(Path(__file__).resolve())
    identity = hashlib.sha256()
    identity.update(suite_manifest_path.read_bytes())
    identity.update(trainer_source_hash.encode("ascii"))
    identity.update(
        json.dumps(
            {
                "model_settings": asdict(model_settings),
                "window_settings": asdict(window_settings),
                "unlock_test": unlock_test,
                "code_commit": code_state["commit"],
            },
            sort_keys=True,
        ).encode("utf-8")
    )
    model_id = (
        f"demand-window-{window_settings.window_minutes}m-hgbr-"
        f"{identity.hexdigest()[:16]}"
    )
    output_root.mkdir(parents=True, exist_ok=True)
    output_dir = output_root / model_id
    incomplete = output_root / f".{model_id}.incomplete"
    if output_dir.exists() or incomplete.exists():
        raise FileExistsError(f"model artifact already exists: {output_dir}")
    incomplete.mkdir()
    model_path = incomplete / "model.joblib"
    joblib.dump(
        {
            "model": model,
            "features": features,
            "target_spec": report["target_spec"],
        },
        model_path,
    )
    write_manifest(report, incomplete / "evaluation_report.json")
    manifest = {
        "model_id": model_id,
        "model_name": "demand_forecasting_rolling_window",
        "model_version": "v1-experiment",
        "created_at": datetime.now(UTC).isoformat(),
        "feature_suite_manifest": _portable_artifact_reference(
            suite_manifest_path, output_dir
        ),
        "feature_suite_manifest_sha256": file_sha256(suite_manifest_path),
        "trainer_source_sha256": trainer_source_hash,
        "training_code": code_state,
        "target_spec": report["target_spec"],
        "artifact": {"path": model_path.name, "sha256": file_sha256(model_path)},
        "evaluation_report": {
            "path": "evaluation_report.json",
            "sha256": file_sha256(incomplete / "evaluation_report.json"),
        },
        "device": "cpu",
        "locked_test_unlocked": unlock_test,
    }
    write_manifest(manifest, incomplete / "manifest.json")
    incomplete.rename(output_dir)
    return output_dir
