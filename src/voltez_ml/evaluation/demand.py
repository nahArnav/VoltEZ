"""Locked-test-safe evaluation for point and rolling-window demand artifacts."""

from __future__ import annotations

import hashlib
import json
import warnings
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, cast

import joblib  # type: ignore[import-untyped]
import numpy as np
import pandas as pd
from numpy.typing import NDArray
from sklearn.inspection import permutation_importance  # type: ignore[import-untyped]
from sklearn.metrics import average_precision_score, roc_auc_score  # type: ignore[import-untyped]

from voltez_ml.synthetic.io import file_sha256, write_manifest
from voltez_ml.training.demand import TARGET, _load_role, _load_suite, _metrics
from voltez_ml.training.demand_window import (
    WINDOW_BASELINE,
    DemandWindowSettings,
    build_rolling_demand_window,
)


@dataclass(frozen=True)
class DemandEvaluationSettings:
    """Controls expensive diagnostics without changing the trained estimator."""

    include_train: bool = False
    include_stress: bool = True
    unlock_test: bool = False
    permutation_sample_rows: int = 50_000
    permutation_repeats: int = 3
    random_seed: int = 20260821

    def __post_init__(self) -> None:
        if self.permutation_sample_rows < 0:
            raise ValueError("permutation sample rows cannot be negative")
        if self.permutation_repeats <= 0:
            raise ValueError("permutation repeats must be positive")


def _finite(value: float | None) -> float | None:
    if value is None or not np.isfinite(value):
        return None
    return float(value)


def _diagnostic_metrics(
    truth: NDArray[np.float64], prediction: NDArray[np.float64]
) -> dict[str, float | None]:
    values = {key: _finite(value) for key, value in _metrics(truth, prediction).items()}
    residual = prediction - truth
    nonzero = truth > 0
    zero = ~nonzero
    values.update(
        {
            "bias_prediction_minus_truth": float(residual.mean()),
            "zero_target_mae": float(np.abs(residual[zero]).mean())
            if bool(zero.any())
            else None,
            "nonzero_underprediction_rate": float(
                (prediction[nonzero] < truth[nonzero]).mean()
            )
            if bool(nonzero.any())
            else None,
            "within_half_request_rate": float((np.abs(residual) <= 0.5).mean()),
            "within_one_request_rate": float((np.abs(residual) <= 1.0).mean()),
        }
    )
    return values


def _prepare_role(
    suite: dict[str, Any], role: str, target_spec: dict[str, Any]
) -> tuple[pd.DataFrame, NDArray[np.float64]]:
    frame = _load_role(suite, role)
    if target_spec.get("kind") == "rolling_sum":
        frame = build_rolling_demand_window(
            frame,
            DemandWindowSettings(
                window_minutes=int(target_spec["window_minutes"]),
                forecast_lead_minutes=int(target_spec["forecast_lead_minutes"]),
                bucket_minutes=int(target_spec["bucket_minutes"]),
            ),
        )
        baseline = frame[WINDOW_BASELINE].to_numpy(dtype="float64")
    else:
        baseline = _target_aligned_seasonal_naive(frame)
    return frame, baseline


def _target_aligned_seasonal_naive(frame: pd.DataFrame) -> NDArray[np.float64]:
    """Use yesterday/week values matching each future target clock slot."""

    keys = ["simulation_run_id", "zone_id"]
    lookup = (
        frame.sort_values([*keys, "prediction_origin", "horizon_minutes"], kind="mergesort")
        .drop_duplicates([*keys, "prediction_origin"])
        [
            [
                *keys,
                "prediction_origin",
                "request_lag_same_time_yesterday",
                "request_lag_same_time_last_week",
            ]
        ]
        .rename(
            columns={
                "prediction_origin": "target_time",
                "request_lag_same_time_yesterday": "target_aligned_yesterday",
                "request_lag_same_time_last_week": "target_aligned_last_week",
            }
        )
    )
    aligned = frame[[*keys, "target_time", "request_ewm_prior"]].merge(
        lookup,
        on=[*keys, "target_time"],
        how="left",
        sort=False,
        validate="many_to_one",
    )
    origin = pd.to_datetime(frame["prediction_origin"]).reset_index(drop=True)
    target = pd.to_datetime(frame["target_time"]).reset_index(drop=True)
    safe_week = target - pd.to_timedelta(7, unit="D") < origin
    safe_yesterday = target - pd.to_timedelta(1, unit="D") < origin
    aligned.loc[~safe_week, "target_aligned_last_week"] = np.nan
    aligned.loc[~safe_yesterday, "target_aligned_yesterday"] = np.nan
    prediction = aligned["target_aligned_last_week"].fillna(
        aligned["target_aligned_yesterday"]
    )
    prediction = prediction.fillna(aligned["request_ewm_prior"]).fillna(0.0)
    return cast(
        NDArray[np.float64],
        np.clip(prediction.to_numpy(dtype="float64"), 0.0, None),
    )


def _nonzero_detection(
    truth: NDArray[np.float64], prediction: NDArray[np.float64]
) -> dict[str, float | None]:
    nonzero = (truth > 0).astype("int8")
    if len(np.unique(nonzero)) < 2:
        return {
            "average_precision": None,
            "roc_auc": None,
            "nonzero_prevalence": float(nonzero.mean()),
            "top_decile_nonzero_precision": None,
            "top_decile_nonzero_capture": None,
        }
    cutoff = float(np.quantile(prediction, 0.9))
    top = prediction >= cutoff
    return {
        "average_precision": float(average_precision_score(nonzero, prediction)),
        "roc_auc": float(roc_auc_score(nonzero, prediction)),
        "nonzero_prevalence": float(nonzero.mean()),
        "top_decile_prediction_cutoff": cutoff,
        "top_decile_nonzero_precision": float(nonzero[top].mean()),
        "top_decile_nonzero_capture": float(nonzero[top].sum() / nonzero.sum()),
    }


def _segment_metrics(frame: pd.DataFrame, group: str) -> list[dict[str, Any]]:
    segments: list[dict[str, Any]] = []
    for name, part in frame.groupby(group, observed=True, sort=True):
        truth = part[TARGET].to_numpy(dtype="float64")
        prediction = part["prediction"].to_numpy(dtype="float64")
        metrics = _diagnostic_metrics(truth, prediction)
        segments.append(
            {
                "segment": str(name),
                "rows": len(part),
                "nonzero_rate": float((truth > 0).mean()),
                "mae": metrics["mae"],
                "rmse": metrics["rmse"],
                "nonzero_mae": metrics["nonzero_mae"],
                "bias": metrics["bias_prediction_minus_truth"],
                "truth_mean": metrics["truth_mean"],
                "prediction_mean": metrics["prediction_mean"],
            }
        )
    return segments


def _calibration(frame: pd.DataFrame) -> list[dict[str, Any]]:
    calibration = frame[[TARGET, "prediction"]].copy()
    calibration["prediction_decile"] = pd.qcut(
        calibration["prediction"], 10, labels=False, duplicates="drop"
    )
    return [
        {
            "decile": int(str(decile)),
            "rows": len(part),
            "prediction_mean": float(part["prediction"].mean()),
            "truth_mean": float(part[TARGET].mean()),
            "nonzero_rate": float((part[TARGET] > 0).mean()),
        }
        for decile, part in calibration.groupby(
            "prediction_decile", observed=True, sort=True
        )
    ]


def _evaluate_role(
    frame: pd.DataFrame,
    baseline: NDArray[np.float64],
    prediction: NDArray[np.float64],
) -> dict[str, Any]:
    evaluated = frame.copy()
    evaluated["prediction"] = prediction
    evaluated["target_hour"] = pd.to_datetime(evaluated["target_time"]).dt.hour
    evaluated["demand_band"] = pd.cut(
        evaluated[TARGET],
        bins=[-0.1, 0.5, 1.5, 2.5, np.inf],
        labels=["0", "1", "2", "3+"],
    )
    truth = evaluated[TARGET].to_numpy(dtype="float64")
    zones = _segment_metrics(evaluated, "zone_id")
    by_horizon = (
        _segment_metrics(evaluated, "horizon_minutes")
        if evaluated["horizon_minutes"].nunique() > 1
        else []
    )
    return {
        "rows": len(evaluated),
        "target_distribution": {
            "zero_rate": float((truth == 0).mean()),
            "mean": float(truth.mean()),
            "max": float(truth.max()),
        },
        "prediction_distribution": {
            "mean": float(prediction.mean()),
            "min": float(prediction.min()),
            "max": float(prediction.max()),
        },
        "model": _diagnostic_metrics(truth, prediction),
        "seasonal_naive": _diagnostic_metrics(truth, baseline),
        "nonzero_detection": _nonzero_detection(truth, prediction),
        "by_demand_band": _segment_metrics(evaluated, "demand_band"),
        "by_horizon": by_horizon,
        "by_hour": _segment_metrics(evaluated, "target_hour"),
        "by_weekend": _segment_metrics(evaluated, "target_is_weekend"),
        "worst_zones_by_mae": sorted(
            zones, key=lambda row: float(row["mae"]), reverse=True
        )[:8],
        "worst_zones_by_absolute_bias": sorted(
            zones, key=lambda row: abs(float(row["bias"])), reverse=True
        )[:8],
        "calibration_deciles": _calibration(evaluated),
    }


def evaluate_demand_model(
    artifact_dir: Path,
    suite_manifest_path: Path,
    output_root: Path,
    settings: DemandEvaluationSettings,
) -> Path:
    """Evaluate validation/stress roles; test is unreachable without explicit unlock."""

    artifact_manifest_path = artifact_dir / "manifest.json"
    artifact_manifest = json.loads(artifact_manifest_path.read_text("utf-8"))
    model_path = artifact_dir / str(artifact_manifest["artifact"]["path"])
    if file_sha256(model_path) != artifact_manifest["artifact"]["sha256"]:
        raise ValueError("model artifact hash does not match its manifest")
    if file_sha256(suite_manifest_path) != artifact_manifest["feature_suite_manifest_sha256"]:
        raise ValueError("feature suite hash does not match the model artifact")
    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore",
            message="Setting the shape on a NumPy array has been deprecated.*",
            category=DeprecationWarning,
        )
        payload = joblib.load(model_path)
    model = payload["model"]
    features = [str(value) for value in payload["features"]]
    target_spec = dict(payload.get("target_spec", {"kind": "point_count"}))
    suite, _ = _load_suite(suite_manifest_path)

    roles = ["validation"]
    if settings.include_stress:
        roles.append("stress_test")
    if settings.include_train:
        roles.insert(0, "train")
    if settings.unlock_test:
        roles.append("test")
    role_reports: dict[str, Any] = {}
    validation_frame: pd.DataFrame | None = None
    for role in roles:
        frame, baseline = _prepare_role(suite, role, target_spec)
        missing = set(features) - set(frame.columns)
        if missing:
            raise ValueError(f"{role} is missing model features: {sorted(missing)}")
        prediction = np.clip(
            model.predict(frame[features].astype("float32")), 0.0, None
        )
        role_reports[role] = _evaluate_role(frame, baseline, prediction)
        if role == "validation":
            validation_frame = frame.assign(prediction=prediction)

    importance_rows: list[dict[str, Any]] = []
    if settings.permutation_sample_rows and validation_frame is not None:
        sample = validation_frame.sample(
            n=min(settings.permutation_sample_rows, len(validation_frame)),
            random_state=settings.random_seed,
        )
        result = permutation_importance(
            model,
            sample[features].astype("float32"),
            sample[TARGET].to_numpy(dtype="float64"),
            scoring="neg_mean_absolute_error",
            n_repeats=settings.permutation_repeats,
            random_state=settings.random_seed,
            n_jobs=1,
        )
        importance_rows = sorted(
            [
                {
                    "feature": feature,
                    "mae_increase_mean": float(mean),
                    "mae_increase_std": float(std),
                }
                for feature, mean, std in zip(
                    features,
                    result.importances_mean,
                    result.importances_std,
                    strict=True,
                )
            ],
            key=lambda row: row["mae_increase_mean"],
            reverse=True,
        )

    report = {
        "created_at": datetime.now(UTC).isoformat(),
        "model_id": artifact_manifest["model_id"],
        "model_artifact_sha256": artifact_manifest["artifact"]["sha256"],
        "feature_suite_manifest_sha256": artifact_manifest[
            "feature_suite_manifest_sha256"
        ],
        "target_spec": target_spec,
        "settings": asdict(settings),
        "integrity": {
            "model_hash_verified": True,
            "feature_suite_hash_verified": True,
            "locked_test_touched": settings.unlock_test,
        },
        "roles": role_reports,
        "permutation_importance": importance_rows,
    }
    identity = hashlib.sha256()
    identity.update(artifact_manifest_path.read_bytes())
    identity.update(json.dumps(asdict(settings), sort_keys=True).encode("utf-8"))
    report_id = f"evaluation-{artifact_manifest['model_id']}-{identity.hexdigest()[:12]}"
    output_root.mkdir(parents=True, exist_ok=True)
    output_dir = output_root / report_id
    incomplete = output_root / f".{report_id}.incomplete"
    if output_dir.exists() or incomplete.exists():
        raise FileExistsError(f"evaluation report already exists: {output_dir}")
    incomplete.mkdir()
    report_path = incomplete / "evaluation_report.json"
    write_manifest(report, report_path)
    write_manifest(
        {
            "report_id": report_id,
            "model_id": artifact_manifest["model_id"],
            "evaluation_report": {
                "path": report_path.name,
                "sha256": file_sha256(report_path),
            },
            "locked_test_touched": settings.unlock_test,
        },
        incomplete / "manifest.json",
    )
    incomplete.rename(output_dir)
    return output_dir
