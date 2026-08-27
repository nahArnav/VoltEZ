"""Model 1 training with independent-world validation and count-aware loss."""

from __future__ import annotations

import hashlib
import json
import os
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, cast

import joblib  # type: ignore[import-untyped]
import numpy as np
import pandas as pd
from numpy.typing import NDArray
from sklearn.ensemble import HistGradientBoostingRegressor  # type: ignore[import-untyped]
from sklearn.metrics import (  # type: ignore[import-untyped]
    mean_absolute_error,
    mean_poisson_deviance,
    mean_squared_error,
)

from voltez_ml.synthetic.io import file_sha256, write_manifest

TARGET = "target_request_count"
NON_FEATURE_COLUMNS = {
    TARGET,
    "zone_id",
    "source_snapshot_id",
    "simulation_run_id",
    "prediction_origin",
    "feature_cutoff",
    "latest_source_time",
    "target_time",
    "split",
    "run_holdout_split",
    "forecast_lead_minutes",
    "target_window_minutes",
    "seasonal_naive_window",
}


@dataclass(frozen=True)
class DemandTrainingSettings:
    max_iter: int = 250
    learning_rate: float = 0.05
    max_leaf_nodes: int = 31
    l2_regularization: float = 0.2
    maximum_training_rows: int = 1_500_000
    random_seed: int = 20260821

    def __post_init__(self) -> None:
        if self.max_iter <= 0:
            raise ValueError("max_iter must be positive")
        if self.learning_rate <= 0:
            raise ValueError("learning_rate must be positive")
        if self.max_leaf_nodes < 2:
            raise ValueError("max_leaf_nodes must be at least 2")
        if self.l2_regularization < 0:
            raise ValueError("l2_regularization cannot be negative")


def _load_suite(path: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    suite = json.loads(path.read_text("utf-8"))
    suite["_manifest_root"] = str(path.parent)
    readiness_path = Path(suite["training_readiness"]["path"])
    if not readiness_path.is_absolute():
        readiness_path = path.parent / readiness_path
    if file_sha256(readiness_path) != suite["training_readiness"]["sha256"]:
        raise ValueError("training-readiness hash does not match the suite manifest")
    readiness = json.loads(readiness_path.read_text("utf-8"))
    demand_readiness = readiness.get("models", {}).get("demand", {})
    if demand_readiness.get("status") != "ready":
        raise ValueError(
            "Model 1 data readiness failed: "
            + "; ".join(str(value) for value in demand_readiness.get("failures", []))
        )
    return suite, readiness


def _paths_for_role(suite: dict[str, Any], role: str) -> list[Path]:
    root = Path(suite["_manifest_root"])
    paths = [
        Path(entry["tables"]["demand_features"])
        for entry in suite["datasets"]
        if entry["evaluation_role"] == role
    ]
    return [path if path.is_absolute() else root / path for path in paths]


def _load_role(suite: dict[str, Any], role: str) -> pd.DataFrame:
    paths = _paths_for_role(suite, role)
    if not paths:
        raise ValueError(f"feature suite has no {role} demand partition")
    frames = [pd.read_parquet(path) for path in paths]
    frame = pd.concat(frames, ignore_index=True)
    if set(frame["run_holdout_split"].astype(str)) != {role}:
        raise ValueError(f"{role} partitions contain a mismatched run-level holdout role")
    return frame


def _feature_columns(frame: pd.DataFrame) -> list[str]:
    columns = [
        str(column)
        for column in frame.select_dtypes(include=[np.number]).columns
        if column not in NON_FEATURE_COLUMNS and frame[column].nunique(dropna=True) > 1
    ]
    if TARGET in columns or not columns:
        raise ValueError("demand feature selection is invalid")
    return columns


def _seasonal_naive(frame: pd.DataFrame) -> NDArray[np.float64]:
    last_week_column = (
        "request_lag_target_time_last_week"
        if "request_lag_target_time_last_week" in frame
        else "request_lag_same_time_last_week"
    )
    yesterday_column = (
        "request_lag_target_time_yesterday"
        if "request_lag_target_time_yesterday" in frame
        else "request_lag_same_time_yesterday"
    )
    prediction = frame[last_week_column].copy()
    prediction = prediction.fillna(frame[yesterday_column])
    prediction = prediction.fillna(frame["request_ewm_prior"])
    return cast(
        NDArray[np.float64],
        np.clip(prediction.fillna(0.0).to_numpy(dtype="float64"), 0.0, None),
    )


def _metrics(
    truth: NDArray[np.float64], prediction: NDArray[np.float64]
) -> dict[str, float | None]:
    clipped = np.clip(prediction, 1e-6, None)
    nonzero = truth > 0
    denominator = float(np.abs(truth).sum())
    return {
        "mae": float(mean_absolute_error(truth, prediction)),
        "rmse": float(mean_squared_error(truth, prediction) ** 0.5),
        "wape": float(np.abs(truth - prediction).sum() / denominator)
        if denominator > 0
        else None,
        "mean_poisson_deviance": float(mean_poisson_deviance(truth, clipped)),
        "nonzero_mae": float(mean_absolute_error(truth[nonzero], prediction[nonzero]))
        if bool(nonzero.any())
        else None,
        "prediction_mean": float(prediction.mean()),
        "truth_mean": float(truth.mean()),
    }


def _sample_training_rows(
    frame: pd.DataFrame,
    maximum_rows: int,
    random_seed: int,
) -> pd.DataFrame:
    if maximum_rows <= 0 or len(frame) <= maximum_rows:
        return frame
    return frame.sample(n=maximum_rows, random_state=random_seed).sort_index()


def _portable_artifact_reference(target: Path, artifact_dir: Path) -> str:
    """Describe an input relative to the artifact so copied repositories remain usable."""

    try:
        return Path(
            os.path.relpath(target.resolve(), start=artifact_dir.resolve())
        ).as_posix()
    except ValueError:
        # Different Windows drives cannot be expressed relatively. The content hash below
        # still identifies the exact input without leaking a machine-specific absolute path.
        return target.name


def train_demand_model(
    suite_manifest_path: Path,
    output_root: Path,
    settings: DemandTrainingSettings,
    unlock_test: bool = False,
) -> Path:
    """Fit Model 1 locally; locked test data is untouched unless explicitly unlocked."""

    suite, readiness = _load_suite(suite_manifest_path)
    train = _sample_training_rows(
        _load_role(suite, "train"),
        settings.maximum_training_rows,
        settings.random_seed,
    )
    validation = _load_role(suite, "validation")
    columns = _feature_columns(train)
    missing_validation = set(columns) - set(validation.columns)
    if missing_validation:
        raise ValueError(f"validation partition is missing features: {sorted(missing_validation)}")

    model = HistGradientBoostingRegressor(
        loss="poisson",
        learning_rate=settings.learning_rate,
        max_iter=settings.max_iter,
        max_leaf_nodes=settings.max_leaf_nodes,
        l2_regularization=settings.l2_regularization,
        early_stopping=False,
        random_state=settings.random_seed,
    )
    train_x = train[columns].astype("float32")
    train_y = train[TARGET].to_numpy(dtype="float64")
    validation_x = validation[columns].astype("float32")
    validation_y = validation[TARGET].to_numpy(dtype="float64")
    model.fit(train_x, train_y)
    validation_prediction = np.clip(model.predict(validation_x), 0.0, None)
    report: dict[str, Any] = {
        "model": "demand_forecasting",
        "algorithm": "HistGradientBoostingRegressor(loss=poisson)",
        "device": "cpu",
        "hardware_note": "scikit-learn does not use Apple MPS; the M4 CPU is the correct device",
        "training_rows": len(train),
        "validation_rows": len(validation),
        "feature_count": len(columns),
        "features": columns,
        "settings": asdict(settings),
        "validation": {
            "seasonal_naive": _metrics(validation_y, _seasonal_naive(validation)),
            "poisson_hist_gradient_boosting": _metrics(
                validation_y, validation_prediction
            ),
        },
        "locked_test_unlocked": unlock_test,
        "data_readiness": readiness["models"]["demand"],
    }
    if unlock_test:
        locked_test = _load_role(suite, "test")
        test_y = locked_test[TARGET].to_numpy(dtype="float64")
        report["locked_test"] = {
            "seasonal_naive": _metrics(test_y, _seasonal_naive(locked_test)),
            "poisson_hist_gradient_boosting": _metrics(
                test_y,
                np.clip(model.predict(locked_test[columns].astype("float32")), 0.0, None),
            ),
        }

    identity = hashlib.sha256()
    identity.update(suite_manifest_path.read_bytes())
    identity.update(
        json.dumps(
            {"settings": asdict(settings), "unlock_test": unlock_test},
            sort_keys=True,
        ).encode("utf-8")
    )
    model_id = f"demand-hgbr-{identity.hexdigest()[:16]}"
    output_root.mkdir(parents=True, exist_ok=True)
    output_dir = output_root / model_id
    incomplete = output_root / f".{model_id}.incomplete"
    if output_dir.exists() or incomplete.exists():
        raise FileExistsError(f"model artifact already exists: {output_dir}")
    incomplete.mkdir()
    model_path = incomplete / "model.joblib"
    joblib.dump({"model": model, "features": columns}, model_path)
    write_manifest(report, incomplete / "evaluation_report.json")
    manifest = {
        "model_id": model_id,
        "model_name": "demand_forecasting",
        "model_version": "v1",
        "created_at": datetime.now(UTC).isoformat(),
        "feature_suite_manifest": _portable_artifact_reference(
            suite_manifest_path, output_dir
        ),
        "feature_suite_manifest_sha256": file_sha256(suite_manifest_path),
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
