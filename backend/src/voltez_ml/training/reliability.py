"""Model 4 training with independent-world calibration and explicit abstention."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, cast

import joblib  # type: ignore[import-untyped]
import numpy as np
import pandas as pd
from numpy.typing import NDArray
from sklearn.compose import ColumnTransformer  # type: ignore[import-untyped]
from sklearn.ensemble import HistGradientBoostingClassifier  # type: ignore[import-untyped]
from sklearn.impute import SimpleImputer  # type: ignore[import-untyped]
from sklearn.inspection import permutation_importance  # type: ignore[import-untyped]
from sklearn.linear_model import LogisticRegression  # type: ignore[import-untyped]
from sklearn.metrics import (  # type: ignore[import-untyped]
    accuracy_score,
    average_precision_score,
    balanced_accuracy_score,
    brier_score_loss,
    confusion_matrix,
    f1_score,
    log_loss,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.pipeline import Pipeline  # type: ignore[import-untyped]
from sklearn.preprocessing import (  # type: ignore[import-untyped]
    OneHotEncoder,
    OrdinalEncoder,
    StandardScaler,
)

from voltez_ml.synthetic.io import file_sha256, write_manifest

TARGET = "label"
POSITIVE_LABEL = "unreliable"
NEGATIVE_LABEL = "reliable"

# This allowlist is deliberately explicit. Entity IDs, target-time evidence, raw timestamps,
# label metadata, and split metadata cannot enter the estimator by accident.
NUMERIC_FEATURE_CANDIDATES = (
    "eta_minutes",
    "target_hour_sin",
    "target_hour_cos",
    "target_day_sin",
    "target_day_cos",
    "target_is_weekend",
    "minutes_to_business_close",
    "known_bookings_near_target",
    "active_session_count",
    "active_session_elapsed_minutes",
    "prior_success_count",
    "prior_failure_count",
    "reliability_evidence_count",
    "smoothed_reliability",
    "cold_start",
    "prior_reliable_session_count",
    "prior_charger_failure_count",
    "prior_congestion_failure_count",
    "charger_reliability_evidence_count",
    "smoothed_charger_reliability",
    "reliability_cold_start",
    "latest_status_confidence",
    "status_age_minutes",
    "status_expired",
    "recent_zone_requests_1h",
    "recent_zone_unserved_1h",
    "recent_zone_occupancy_mean_1h",
    "max_power_kw",
    "site_port_count",
)

CATEGORICAL_FEATURE_CANDIDATES = (
    "latest_status",
    "latest_status_source",
    "connector_code",
    "charging_type",
    "business_category",
    "access_type",
)

NON_FEATURE_COLUMNS = {
    "reliability_observation_id",
    "request_id",
    "port_id",
    "charger_id",
    "zone_id",
    "simulation_run_id",
    "source_snapshot_id",
    "prediction_origin",
    "feature_cutoff",
    "target_time",
    "latest_booking_event_at",
    "latest_session_event_at",
    "status_ingested_at_feature",
    "demand_cutoff_at",
    "latest_source_time",
    "label",
    "label_known",
    "label_source",
    "availability_observation_id",
    "label_failure_reason",
    "booking_id",
    "session_id",
    "target_arrival_at",
    "label_observed_at",
    "split",
    "run_holdout_split",
}

FloatArray = NDArray[np.float64]
IntArray = NDArray[np.int64]


@dataclass(frozen=True)
class ReliabilityFeatureSpec:
    numeric: tuple[str, ...]
    categorical: tuple[str, ...]

    @property
    def all(self) -> tuple[str, ...]:
        return (*self.numeric, *self.categorical)


@dataclass(frozen=True)
class ReliabilityTrainingSettings:
    max_iter: int = 250
    learning_rate: float = 0.05
    max_leaf_nodes: int = 31
    min_samples_leaf: int = 30
    l2_regularization: float = 0.5
    target_reliable_risk: float = 0.05
    target_unreliable_precision: float = 0.60
    minimum_threshold_rows: int = 100
    permutation_sample_rows: int = 10_000
    permutation_repeats: int = 3
    random_seed: int = 20260822

    def __post_init__(self) -> None:
        if self.max_iter <= 0:
            raise ValueError("max_iter must be positive")
        if self.learning_rate <= 0:
            raise ValueError("learning_rate must be positive")
        if self.max_leaf_nodes < 2:
            raise ValueError("max_leaf_nodes must be at least 2")
        if self.min_samples_leaf < 2:
            raise ValueError("min_samples_leaf must be at least 2")
        if self.l2_regularization < 0:
            raise ValueError("l2_regularization cannot be negative")
        if not 0 < self.target_reliable_risk < 0.5:
            raise ValueError("target_reliable_risk must be between zero and 0.5")
        if not 0.5 <= self.target_unreliable_precision <= 1:
            raise ValueError("target_unreliable_precision must be between 0.5 and 1")
        if self.minimum_threshold_rows <= 0:
            raise ValueError("minimum_threshold_rows must be positive")
        if self.permutation_sample_rows < 0:
            raise ValueError("permutation_sample_rows cannot be negative")
        if self.permutation_repeats <= 0:
            raise ValueError("permutation_repeats must be positive")


def _load_suite(path: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    suite = json.loads(path.read_text("utf-8"))
    suite["_manifest_root"] = str(path.parent)
    readiness_path = Path(suite["training_readiness"]["path"])
    if not readiness_path.is_absolute():
        readiness_path = path.parent / readiness_path
    if file_sha256(readiness_path) != suite["training_readiness"]["sha256"]:
        raise ValueError("training-readiness hash does not match the suite manifest")
    readiness = json.loads(readiness_path.read_text("utf-8"))
    status = readiness.get("models", {}).get("reliability", {})
    if status.get("status") != "ready":
        raise ValueError(
            "Model 4 data readiness failed: "
            + "; ".join(str(value) for value in status.get("failures", []))
        )
    return suite, readiness


def _load_role(suite: dict[str, Any], role: str, unlock_test: bool = False) -> pd.DataFrame:
    if role == "test" and not unlock_test:
        raise ValueError("locked test access is forbidden during Model 4 development")
    root = Path(suite["_manifest_root"])
    entries = [entry for entry in suite["datasets"] if entry["evaluation_role"] == role]
    if not entries:
        raise ValueError(f"feature suite has no {role} reliability partition")
    frames: list[pd.DataFrame] = []
    for entry in entries:
        path = Path(entry["tables"]["reliability_features_labeled"])
        frames.append(pd.read_parquet(path if path.is_absolute() else root / path))
    frame = pd.concat(frames, ignore_index=True)
    if set(frame["run_holdout_split"].astype(str)) != {role}:
        raise ValueError(f"{role} reliability rows contain a mismatched holdout role")
    if set(frame[TARGET].astype(str)) != {NEGATIVE_LABEL, POSITIVE_LABEL}:
        raise ValueError(f"{role} reliability partition must contain both known labels")
    return frame


def _feature_spec(train: pd.DataFrame) -> ReliabilityFeatureSpec:
    numeric = tuple(
        column
        for column in NUMERIC_FEATURE_CANDIDATES
        if column in train and train[column].nunique(dropna=True) > 1
    )
    categorical = tuple(
        column
        for column in CATEGORICAL_FEATURE_CANDIDATES
        if column in train and train[column].nunique(dropna=True) > 1
    )
    if not numeric or not categorical:
        raise ValueError("reliability feature contract requires numeric and categorical inputs")
    selected = set((*numeric, *categorical))
    forbidden = selected & NON_FEATURE_COLUMNS
    if forbidden:
        raise ValueError(f"forbidden reliability features selected: {sorted(forbidden)}")
    return ReliabilityFeatureSpec(numeric=numeric, categorical=categorical)


def _model_frame(frame: pd.DataFrame, spec: ReliabilityFeatureSpec) -> pd.DataFrame:
    missing = set(spec.all) - set(frame.columns)
    if missing:
        raise ValueError(f"reliability frame is missing features: {sorted(missing)}")
    result = frame[list(spec.all)].copy()
    for column in spec.numeric:
        result[column] = pd.to_numeric(result[column], errors="coerce").astype("float64")
    for column in spec.categorical:
        result[column] = result[column].astype("string").fillna("__missing__").astype(str)
    return result


def _target(frame: pd.DataFrame) -> IntArray:
    return cast(IntArray, (frame[TARGET].astype(str) == POSITIVE_LABEL).to_numpy(dtype="int64"))


def _confidence_weight(frame: pd.DataFrame) -> FloatArray:
    if "availability_observation_id" not in frame:
        return np.ones(len(frame), dtype="float64")
    return cast(
        FloatArray,
        pd.to_numeric(frame["availability_observation_id"], errors="coerce")
        .fillna(1.0)
        .clip(lower=0.01, upper=1.0)
        .to_numpy(dtype="float64"),
    )


def _candidate_pipeline(
    spec: ReliabilityFeatureSpec,
    settings: ReliabilityTrainingSettings,
) -> Pipeline:
    categorical = Pipeline(
        [
            ("impute", SimpleImputer(strategy="constant", fill_value="__missing__")),
            (
                "encode",
                OrdinalEncoder(
                    handle_unknown="use_encoded_value",
                    unknown_value=np.nan,
                    encoded_missing_value=np.nan,
                    dtype=np.float64,
                ),
            ),
        ]
    )
    transform = ColumnTransformer(
        [
            ("numeric", "passthrough", list(spec.numeric)),
            ("categorical", categorical, list(spec.categorical)),
        ],
        remainder="drop",
        sparse_threshold=0.0,
        verbose_feature_names_out=False,
    )
    categorical_mask = [False] * len(spec.numeric) + [True] * len(spec.categorical)
    model = HistGradientBoostingClassifier(
        loss="log_loss",
        learning_rate=settings.learning_rate,
        max_iter=settings.max_iter,
        max_leaf_nodes=settings.max_leaf_nodes,
        min_samples_leaf=settings.min_samples_leaf,
        l2_regularization=settings.l2_regularization,
        categorical_features=categorical_mask,
        early_stopping=False,
        class_weight="balanced",
        random_state=settings.random_seed,
    )
    return Pipeline([("transform", transform), ("model", model)])


def _logistic_pipeline(
    spec: ReliabilityFeatureSpec,
    settings: ReliabilityTrainingSettings,
) -> Pipeline:
    numeric = Pipeline(
        [
            ("impute", SimpleImputer(strategy="median")),
            ("scale", StandardScaler()),
        ]
    )
    categorical = Pipeline(
        [
            ("impute", SimpleImputer(strategy="constant", fill_value="__missing__")),
            ("encode", OneHotEncoder(handle_unknown="ignore")),
        ]
    )
    transform = ColumnTransformer(
        [
            ("numeric", numeric, list(spec.numeric)),
            ("categorical", categorical, list(spec.categorical)),
        ],
        remainder="drop",
    )
    model = LogisticRegression(
        solver="lbfgs",
        max_iter=1_000,
        random_state=settings.random_seed,
    )
    return Pipeline([("transform", transform), ("model", model)])


def _fit_pipeline(
    model: Pipeline,
    frame: pd.DataFrame,
    spec: ReliabilityFeatureSpec,
    weight: FloatArray,
) -> Pipeline:
    model.fit(_model_frame(frame, spec), _target(frame), model__sample_weight=weight)
    return model


def _positive_probability(
    model: Pipeline,
    frame: pd.DataFrame,
    spec: ReliabilityFeatureSpec,
) -> FloatArray:
    probability = model.predict_proba(_model_frame(frame, spec))[:, 1]
    return cast(FloatArray, np.clip(probability.astype("float64"), 1e-6, 1 - 1e-6))


def _logit(probability: FloatArray) -> NDArray[np.float64]:
    clipped = np.clip(probability, 1e-6, 1 - 1e-6)
    return cast(NDArray[np.float64], np.log(clipped / (1 - clipped)).reshape(-1, 1))


def _out_of_world_probability(
    train: pd.DataFrame,
    spec: ReliabilityFeatureSpec,
    settings: ReliabilityTrainingSettings,
) -> FloatArray:
    worlds = sorted(train["simulation_run_id"].astype(str).unique())
    if len(worlds) < 2:
        raise ValueError("calibration requires at least two independent training worlds")
    probability = np.full(len(train), np.nan, dtype="float64")
    run_id = train["simulation_run_id"].astype(str)
    for held_out_world in worlds:
        held_out = run_id == held_out_world
        fitted = _fit_pipeline(
            _candidate_pipeline(spec, settings),
            train.loc[~held_out],
            spec,
            _confidence_weight(train.loc[~held_out]),
        )
        probability[held_out.to_numpy()] = _positive_probability(fitted, train.loc[held_out], spec)
    if not bool(np.isfinite(probability).all()):
        raise ValueError("out-of-world calibration probabilities are incomplete")
    return probability


def _fit_calibrator(
    raw_probability: FloatArray,
    truth: IntArray,
    weight: FloatArray,
    random_seed: int,
) -> LogisticRegression:
    calibrator = LogisticRegression(
        solver="lbfgs",
        C=1_000.0,
        max_iter=1_000,
        random_state=random_seed,
    )
    calibrator.fit(_logit(raw_probability), truth, sample_weight=weight)
    return calibrator


def _calibrated_probability(
    calibrator: LogisticRegression,
    raw_probability: FloatArray,
) -> FloatArray:
    return cast(
        FloatArray,
        np.clip(
            calibrator.predict_proba(_logit(raw_probability))[:, 1].astype("float64"),
            1e-6,
            1 - 1e-6,
        ),
    )


def _expected_calibration_error(
    truth: IntArray,
    probability: FloatArray,
    bins: int = 10,
) -> float:
    assignments = np.minimum((probability * bins).astype("int64"), bins - 1)
    error = 0.0
    for index in range(bins):
        selected = assignments == index
        if bool(selected.any()):
            error += float(selected.mean()) * abs(
                float(probability[selected].mean()) - float(truth[selected].mean())
            )
    return error


def _probability_metrics(
    truth: IntArray,
    probability: FloatArray,
    threshold: float = 0.5,
) -> dict[str, Any]:
    prediction = (probability >= threshold).astype("int64")
    tn, fp, fn, tp = confusion_matrix(truth, prediction, labels=[0, 1]).ravel()
    return {
        "rows": len(truth),
        "unreliable_prevalence": float(truth.mean()),
        "predicted_unreliable_rate": float(prediction.mean()),
        "probability_mean": float(probability.mean()),
        "roc_auc": float(roc_auc_score(truth, probability)),
        "average_precision": float(average_precision_score(truth, probability)),
        "log_loss": float(log_loss(truth, probability, labels=[0, 1])),
        "brier_score": float(brier_score_loss(truth, probability)),
        "expected_calibration_error_10_bins": _expected_calibration_error(truth, probability),
        "accuracy_at_0_5": float(accuracy_score(truth, prediction)),
        "balanced_accuracy_at_0_5": float(balanced_accuracy_score(truth, prediction)),
        "unreliable_precision_at_0_5": float(precision_score(truth, prediction, zero_division=0)),
        "unreliable_recall_at_0_5": float(recall_score(truth, prediction, zero_division=0)),
        "unreliable_f1_at_0_5": float(f1_score(truth, prediction, zero_division=0)),
        "confusion_at_0_5": {
            "true_reliable_predicted_reliable": int(tn),
            "true_reliable_predicted_unreliable": int(fp),
            "true_unreliable_predicted_reliable": int(fn),
            "true_unreliable_predicted_unreliable": int(tp),
        },
    }


def _status_heuristic(frame: pd.DataFrame, prior: float) -> FloatArray:
    status = frame["latest_status"].astype(str)
    probability = np.full(len(frame), prior, dtype="float64")
    fresh = frame["status_expired"].to_numpy(dtype="int64") == 0
    probability[fresh & status.eq("reliable").to_numpy()] = 0.03
    probability[fresh & status.eq("occupied").to_numpy()] = 0.65
    probability[fresh & status.eq("faulted").to_numpy()] = 0.95
    return cast(FloatArray, np.clip(probability, 1e-6, 1 - 1e-6))


def _select_thresholds(
    truth: IntArray,
    probability: FloatArray,
    settings: ReliabilityTrainingSettings,
) -> dict[str, Any]:
    reliable_candidates: list[tuple[float, float, int]] = []
    for threshold in np.linspace(0.001, 0.40, 200):
        selected = probability <= threshold
        rows = int(selected.sum())
        if rows < settings.minimum_threshold_rows:
            continue
        risk = float(truth[selected].mean())
        if risk <= settings.target_reliable_risk:
            reliable_candidates.append((float(threshold), risk, rows))
    if reliable_candidates:
        reliable_threshold, reliable_risk, reliable_rows = max(
            reliable_candidates, key=lambda value: value[2]
        )
        reliable_rule = "maximum coverage satisfying reliable-risk target"
    else:
        fallbacks: list[tuple[float, float, int]] = []
        for threshold in np.linspace(0.001, 0.40, 200):
            selected = probability <= threshold
            rows = int(selected.sum())
            if rows >= settings.minimum_threshold_rows:
                fallbacks.append((float(threshold), float(truth[selected].mean()), rows))
        if not fallbacks:
            raise ValueError("validation data cannot support an reliable threshold")
        reliable_threshold, reliable_risk, reliable_rows = min(
            fallbacks, key=lambda value: (value[1], -value[2])
        )
        reliable_rule = "lowest observed risk because target was unattainable"

    unreliable_candidates: list[tuple[float, float, float, int]] = []
    lower = max(reliable_threshold + 0.01, 0.02)
    positive_rows = max(1, int(truth.sum()))
    for threshold in np.linspace(lower, 0.99, 250):
        selected = probability >= threshold
        rows = int(selected.sum())
        if rows < settings.minimum_threshold_rows:
            continue
        precision = float(truth[selected].mean())
        recall = float(int(truth[selected].sum()) / positive_rows)
        if precision >= settings.target_unreliable_precision:
            unreliable_candidates.append((float(threshold), precision, recall, rows))
    if unreliable_candidates:
        unreliable_threshold, unreliable_precision, unreliable_recall, unreliable_rows = max(
            unreliable_candidates, key=lambda value: (value[2], value[3])
        )
        unreliable_rule = "maximum recall satisfying unreliable-precision target"
    else:
        fallbacks_2: list[tuple[float, float, float, int, float]] = []
        for threshold in np.linspace(lower, 0.99, 250):
            selected = probability >= threshold
            rows = int(selected.sum())
            if rows < settings.minimum_threshold_rows:
                continue
            precision = float(truth[selected].mean())
            recall = float(int(truth[selected].sum()) / positive_rows)
            f1 = float(2 * precision * recall / max(1e-12, precision + recall))
            fallbacks_2.append((float(threshold), precision, recall, rows, f1))
        if not fallbacks_2:
            raise ValueError("validation data cannot support an unreliable threshold")
        fallback_threshold, fallback_precision, fallback_recall, fallback_rows, _ = max(
            fallbacks_2, key=lambda value: value[4]
        )
        unreliable_threshold = fallback_threshold
        unreliable_precision = fallback_precision
        unreliable_recall = fallback_recall
        unreliable_rows = fallback_rows
        unreliable_rule = "best F1 because precision target was unattainable"

    return {
        "reliable_max_probability_unreliable": reliable_threshold,
        "unreliable_min_probability_unreliable": unreliable_threshold,
        "reliable_selection": {
            "rule": reliable_rule,
            "validation_rows": reliable_rows,
            "observed_unreliable_risk": reliable_risk,
            "target_maximum_risk": settings.target_reliable_risk,
        },
        "unreliable_selection": {
            "rule": unreliable_rule,
            "validation_rows": unreliable_rows,
            "observed_precision": unreliable_precision,
            "observed_recall": unreliable_recall,
            "target_minimum_precision": settings.target_unreliable_precision,
        },
    }


def _decision_metrics(
    truth: IntArray,
    probability: FloatArray,
    thresholds: dict[str, Any],
) -> dict[str, Any]:
    low = float(thresholds["reliable_max_probability_unreliable"])
    high = float(thresholds["unreliable_min_probability_unreliable"])
    state = np.full(len(truth), "unknown", dtype=object)
    state[probability <= low] = NEGATIVE_LABEL
    state[probability >= high] = POSITIVE_LABEL
    decided = state != "unknown"
    reliable = state == NEGATIVE_LABEL
    unreliable = state == POSITIVE_LABEL
    predicted_binary = unreliable.astype("int64")
    return {
        "coverage": float(decided.mean()),
        "abstention_rate": float((~decided).mean()),
        "reliable_rate": float(reliable.mean()),
        "unreliable_rate": float(unreliable.mean()),
        "decided_accuracy": float((predicted_binary[decided] == truth[decided]).mean())
        if bool(decided.any())
        else None,
        "reliable_precision": float((truth[reliable] == 0).mean())
        if bool(reliable.any())
        else None,
        "unsafe_reliable_rate": float(truth[reliable].mean()) if bool(reliable.any()) else None,
        "unreliable_precision": float(truth[unreliable].mean()) if bool(unreliable.any()) else None,
        "unreliable_recall": float(truth[unreliable].sum() / max(1, truth.sum())),
        "counts": {
            NEGATIVE_LABEL: int(reliable.sum()),
            "unknown": int((~decided).sum()),
            POSITIVE_LABEL: int(unreliable.sum()),
        },
    }


def _segment_metrics(
    frame: pd.DataFrame,
    probability: FloatArray,
    column: str,
) -> list[dict[str, Any]]:
    evaluated = pd.DataFrame(
        {
            "segment": frame[column].astype(str).to_numpy(),
            "truth": _target(frame),
            "probability": probability,
        }
    )
    rows: list[dict[str, Any]] = []
    for segment, part in evaluated.groupby("segment", sort=True, observed=True):
        truth = part["truth"].to_numpy(dtype="int64")
        score = part["probability"].to_numpy(dtype="float64")
        rows.append(
            {
                "segment": str(segment),
                "rows": len(part),
                "unreliable_rate": float(truth.mean()),
                "probability_mean": float(score.mean()),
                "brier_score": float(brier_score_loss(truth, score)),
                "average_precision": float(average_precision_score(truth, score))
                if len(np.unique(truth)) == 2
                else None,
            }
        )
    return rows


def _permutation_importance_report(
    model: Pipeline,
    validation: pd.DataFrame,
    spec: ReliabilityFeatureSpec,
    settings: ReliabilityTrainingSettings,
) -> list[dict[str, float | str]]:
    if settings.permutation_sample_rows == 0:
        return []
    sample_rows = min(settings.permutation_sample_rows, len(validation))
    sample = validation.sample(n=sample_rows, random_state=settings.random_seed)
    result = permutation_importance(
        model,
        _model_frame(sample, spec),
        _target(sample),
        scoring="average_precision",
        n_repeats=settings.permutation_repeats,
        random_state=settings.random_seed,
        n_jobs=1,
    )
    rows: list[dict[str, float | str]] = []
    for feature, mean, std in zip(
        spec.all, result.importances_mean, result.importances_std, strict=True
    ):
        rows.append(
            {
                "feature": feature,
                "average_precision_decrease_mean": float(mean),
                "average_precision_decrease_std": float(std),
            }
        )
    return sorted(
        rows,
        key=lambda row: float(row["average_precision_decrease_mean"]),
        reverse=True,
    )


def _role_report(
    frame: pd.DataFrame,
    train_prevalence: float,
    logistic_probability: FloatArray,
    raw_probability: FloatArray,
    calibrated_probability: FloatArray,
    thresholds: dict[str, Any],
) -> dict[str, Any]:
    truth = _target(frame)
    always_reliable = np.full(len(frame), 1e-6, dtype="float64")
    prevalence_constant = np.full(len(frame), train_prevalence, dtype="float64")
    status_probability = _status_heuristic(frame, train_prevalence)
    return {
        "rows": len(frame),
        "labels": {
            NEGATIVE_LABEL: int((truth == 0).sum()),
            POSITIVE_LABEL: int((truth == 1).sum()),
        },
        "baselines": {
            "always_reliable": _probability_metrics(truth, always_reliable),
            "training_prevalence_constant": _probability_metrics(truth, prevalence_constant),
            "latest_fresh_status": _probability_metrics(truth, status_probability),
            "logistic_regression": _probability_metrics(truth, logistic_probability),
        },
        "hist_gradient_boosting_raw": _probability_metrics(truth, raw_probability),
        "hist_gradient_boosting_calibrated": _probability_metrics(truth, calibrated_probability),
        "three_state_decision": _decision_metrics(truth, calibrated_probability, thresholds),
        "segments": {
            column: _segment_metrics(frame, calibrated_probability, column)
            for column in (
                "eta_minutes",
                "latest_status",
                "status_expired",
                "active_session_count",
                "reliability_cold_start",
            )
        },
    }


def _development_gates(
    validation: dict[str, Any],
    stress: dict[str, Any],
    settings: ReliabilityTrainingSettings,
) -> dict[str, Any]:
    validation_model = validation["hist_gradient_boosting_calibrated"]
    validation_prior = validation["baselines"]["training_prevalence_constant"]
    validation_decision = validation["three_state_decision"]
    stress_decision = stress["three_state_decision"]
    checks = {
        "validation_roc_auc_at_least_0_75": validation_model["roc_auc"] >= 0.75,
        "validation_pr_auc_at_least_twice_prevalence": (
            validation_model["average_precision"] >= 2 * validation_model["unreliable_prevalence"]
        ),
        "validation_brier_better_than_prevalence_baseline": (
            validation_model["brier_score"] < validation_prior["brier_score"]
        ),
        "validation_calibration_error_at_most_0_03": (
            validation_model["expected_calibration_error_10_bins"] <= 0.03
        ),
        "validation_reliable_risk_meets_target": (
            validation_decision["unsafe_reliable_rate"] <= settings.target_reliable_risk + 1e-12
        ),
        "stress_reliable_risk_at_most_target_plus_0_02": (
            stress_decision["unsafe_reliable_rate"] <= settings.target_reliable_risk + 0.02
        ),
        "stress_unreliable_precision_at_least_0_50": (
            stress_decision["unreliable_precision"] is not None
            and stress_decision["unreliable_precision"] >= 0.50
        ),
    }
    failures = [name for name, passed in checks.items() if not passed]
    return {
        "status": "passed" if not failures else "failed",
        "checks": checks,
        "failures": failures,
        "scope": "development only; does not unlock or replace final test evaluation",
    }


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


def _portable_reference(target: Path, artifact_dir: Path) -> str:
    try:
        return Path(os.path.relpath(target.resolve(), start=artifact_dir.resolve())).as_posix()
    except ValueError:
        return target.name


def train_reliability_model(
    suite_manifest_path: Path,
    output_root: Path,
    settings: ReliabilityTrainingSettings,
    unlock_test: bool = False,
) -> Path:
    """Train and evaluate Model 4 without opening the locked test partition."""

    suite, readiness = _load_suite(suite_manifest_path)
    train = _load_role(suite, "train")
    validation = _load_role(suite, "validation")
    stress = _load_role(suite, "stress_test")
    spec = _feature_spec(train)
    train_truth = _target(train)
    train_weight = _confidence_weight(train)
    train_prevalence = float(train_truth.mean())

    oof_raw = _out_of_world_probability(train, spec, settings)
    calibrator = _fit_calibrator(
        oof_raw,
        train_truth,
        train_weight,
        settings.random_seed,
    )
    oof_calibrated = _calibrated_probability(calibrator, oof_raw)

    candidate = _fit_pipeline(_candidate_pipeline(spec, settings), train, spec, train_weight)
    logistic = _fit_pipeline(_logistic_pipeline(spec, settings), train, spec, train_weight)

    validation_raw = _positive_probability(candidate, validation, spec)
    validation_calibrated = _calibrated_probability(calibrator, validation_raw)
    validation_logistic = _positive_probability(logistic, validation, spec)
    thresholds = _select_thresholds(_target(validation), validation_calibrated, settings)
    stress_raw = _positive_probability(candidate, stress, spec)
    stress_calibrated = _calibrated_probability(calibrator, stress_raw)
    stress_logistic = _positive_probability(logistic, stress, spec)
    validation_report = _role_report(
        validation,
        train_prevalence,
        validation_logistic,
        validation_raw,
        validation_calibrated,
        thresholds,
    )
    stress_report = _role_report(
        stress,
        train_prevalence,
        stress_logistic,
        stress_raw,
        stress_calibrated,
        thresholds,
    )

    project_root = Path.cwd().resolve()
    code_state = _git_state(project_root)
    trainer_source_hash = file_sha256(Path(__file__).resolve())
    identity = hashlib.sha256()
    identity.update(suite_manifest_path.read_bytes())
    identity.update(trainer_source_hash.encode("ascii"))
    identity.update(
        json.dumps(
            {
                "settings": asdict(settings),
                "code_commit": code_state["commit"],
            },
            sort_keys=True,
        ).encode("utf-8")
    )
    model_id = f"reliability-hgb-calibrated-{identity.hexdigest()[:16]}"
    output_root.mkdir(parents=True, exist_ok=True)
    output_dir = output_root / model_id
    incomplete = output_root / f".{model_id}.incomplete"
    if output_dir.exists() or incomplete.exists():
        raise FileExistsError(f"model artifact already exists: {output_dir}")
    incomplete.mkdir()

    report: dict[str, Any] = {
        "model": "charger_reliability_prediction",
        "model_id": model_id,
        "positive_class": POSITIVE_LABEL,
        "negative_class": NEGATIVE_LABEL,
        "algorithm": "HistGradientBoostingClassifier + out-of-world Platt calibration",
        "device": "cpu",
        "hardware_note": "scikit-learn histogram boosting uses the Apple M4 CPU, not MPS",
        "locked_test_unlocked": unlock_test,
        "locked_test_accessed": unlock_test,
        "training_rows": len(train),
        "training_worlds": int(train["simulation_run_id"].nunique()),
        "training_unreliable_prevalence": train_prevalence,
        "feature_count": len(spec.all),
        "feature_spec": asdict(spec),
        "forbidden_feature_columns": sorted(NON_FEATURE_COLUMNS),
        "settings": asdict(settings),
        "hard_gate_policy": [
            "connector compatibility",
            "business and host access",
            "approved reliability window",
            "known active fault or maintenance",
            "confirmed overlapping booking",
            "verification and suspension policy",
        ],
        "missing_status_policy": "abstain as unknown in serving; do not invent a binary state",
        "calibration": {
            "method": "Platt sigmoid on probabilities from leave-one-training-world-out fits",
            "uses_validation_labels": False,
            "out_of_world_raw": _probability_metrics(train_truth, oof_raw),
            "out_of_world_calibrated": _probability_metrics(train_truth, oof_calibrated),
        },
        "thresholds": thresholds,
        "validation_permutation_importance": _permutation_importance_report(
            candidate, validation, spec, settings
        ),
        "validation": validation_report,
        "stress_test": stress_report,
        "development_gates": _development_gates(validation_report, stress_report, settings),
        "data_readiness": readiness["models"]["reliability"],
        "code_state": code_state,
    }

    if unlock_test:
        locked_test = _load_role(suite, "test", unlock_test=unlock_test)
        locked_test_raw = _positive_probability(candidate, locked_test, spec)
        locked_test_calibrated = _calibrated_probability(calibrator, locked_test_raw)
        locked_test_logistic = _positive_probability(logistic, locked_test, spec)
        report["locked_test"] = _role_report(
            locked_test,
            train_prevalence,
            locked_test_logistic,
            locked_test_raw,
            locked_test_calibrated,
            thresholds,
        )

    model_path = incomplete / "model.joblib"
    joblib.dump(
        {
            "base_model": candidate,
            "calibrator": calibrator,
            "feature_spec": asdict(spec),
            "positive_class": POSITIVE_LABEL,
            "negative_class": NEGATIVE_LABEL,
            "thresholds": thresholds,
            "missing_status_policy": "unknown",
        },
        model_path,
    )
    report_path = incomplete / "evaluation_report.json"
    write_manifest(report, report_path)
    manifest = {
        "model_id": model_id,
        "model_name": "charger_reliability_prediction",
        "model_version": "v1",
        "created_at": datetime.now(UTC).isoformat(),
        "feature_suite_manifest": _portable_reference(suite_manifest_path, output_dir),
        "feature_suite_manifest_sha256": file_sha256(suite_manifest_path),
        "trainer_source_sha256": trainer_source_hash,
        "artifact": {"path": model_path.name, "sha256": file_sha256(model_path)},
        "evaluation_report": {
            "path": report_path.name,
            "sha256": file_sha256(report_path),
        },
        "code_state": code_state,
        "device": "cpu",
        "locked_test_unlocked": unlock_test,
        "locked_test_accessed": unlock_test,
    }
    write_manifest(manifest, incomplete / "manifest.json")
    incomplete.rename(output_dir)
    return output_dir
