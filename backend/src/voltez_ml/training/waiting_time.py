"""Two-stage hurdle model for waiting time prediction."""

from __future__ import annotations

import hashlib
import json
import os
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Self, cast

import joblib  # type: ignore[import-untyped]
import numpy as np
import pandas as pd
from numpy.typing import NDArray
from sklearn.base import BaseEstimator, RegressorMixin  # type: ignore[import-untyped]
from sklearn.compose import ColumnTransformer  # type: ignore[import-untyped]
from sklearn.ensemble import (  # type: ignore[import-untyped]
    HistGradientBoostingClassifier,
    HistGradientBoostingRegressor,
)
from sklearn.metrics import (  # type: ignore[import-untyped]
    average_precision_score,
    brier_score_loss,
    log_loss,
    mean_absolute_error,
    roc_auc_score,
)
from sklearn.preprocessing import OrdinalEncoder  # type: ignore[import-untyped]

from voltez_ml.synthetic.io import file_sha256, write_manifest

TARGET = "label_wait_minutes"

NON_FEATURE_COLUMNS = {
    TARGET,
    "simulation_run_id",
    "request_id",
    "port_id",
    "waiting_observation_id",
    "booking_id",
    "session_id",
    "target_arrival_at",
    "actual_arrival_at",
    "label_known",
    "label_source",
    "label_observed_at",
    "outcome",
    "availability_observation_id",
    "charger_id",
    "zone_id",
    "source_snapshot_id",
    "prediction_origin",
    "feature_cutoff",
    "latest_booking_event_at",
    "latest_session_event_at",
    "status_ingested_at_feature",
    "demand_cutoff_at",
    "latest_source_time",
    "target_time",
    "latest_wait_observed_at_feature",
    "split",
    "run_holdout_split",
}


@dataclass(frozen=True)
class WaitingTimeTrainingSettings:
    """Hyperparameters for the occurrence and positive-count boosting stages."""

    classifier_max_iter: int = 250
    count_max_iter: int = 250
    classifier_learning_rate: float = 0.05
    count_learning_rate: float = 0.05
    classifier_max_leaf_nodes: int = 31
    count_max_leaf_nodes: int = 31
    classifier_l2_regularization: float = 0.2
    count_l2_regularization: float = 0.2
    maximum_training_rows: int = 1_500_000
    random_seed: int = 20260821

    def __post_init__(self) -> None:
        if self.classifier_max_iter <= 0 or self.count_max_iter <= 0:
            raise ValueError("both max-iteration values must be positive")
        if self.classifier_learning_rate <= 0 or self.count_learning_rate <= 0:
            raise ValueError("both learning rates must be positive")
        if self.classifier_max_leaf_nodes < 2 or self.count_max_leaf_nodes < 2:
            raise ValueError("both max-leaf-node values must be at least 2")
        if self.classifier_l2_regularization < 0:
            raise ValueError("classifier L2 regularization cannot be negative")
        if self.count_l2_regularization < 0:
            raise ValueError("count L2 regularization cannot be negative")
        if self.maximum_training_rows <= 0:
            raise ValueError("maximum training rows must be positive")


def _load_suite(path: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    suite = json.loads(path.read_text("utf-8"))
    suite["_manifest_root"] = str(path.parent)
    readiness_path = Path(suite["training_readiness"]["path"])
    if not readiness_path.is_absolute():
        readiness_path = path.parent / readiness_path
    if file_sha256(readiness_path) != suite["training_readiness"]["sha256"]:
        raise ValueError("training-readiness hash does not match the suite manifest")
    readiness = json.loads(readiness_path.read_text("utf-8"))
    status = readiness.get("models", {}).get("waiting_time", {})
    if status.get("status") != "ready":
        raise ValueError(
            "Model 3 data readiness failed: "
            + "; ".join(str(value) for value in status.get("failures", []))
        )
    return suite, readiness


def _load_role(suite: dict[str, Any], role: str, unlock_test: bool = False) -> pd.DataFrame:
    root = Path(suite["_manifest_root"])
    entries = [entry for entry in suite["datasets"] if entry["evaluation_role"] == role]
    if not entries:
        raise ValueError(f"feature suite has no {role} waiting_time partition")
    frames: list[pd.DataFrame] = []
    for entry in entries:
        path = Path(entry["tables"]["waiting_time_features_labeled"])
        frames.append(pd.read_parquet(path if path.is_absolute() else root / path))
    frame = pd.concat(frames, ignore_index=True)
    if set(frame["run_holdout_split"].astype(str)) != {role}:
        raise ValueError(f"{role} waiting_time rows contain a mismatched holdout role")
    return frame


def _feature_spec(frame: pd.DataFrame) -> tuple[list[str], list[str]]:
    numeric = []
    categorical = []
    for col in frame.columns:
        if col in NON_FEATURE_COLUMNS or frame[col].nunique(dropna=True) <= 1:
            continue
        if pd.api.types.is_numeric_dtype(frame[col]):
            numeric.append(str(col))
        else:
            categorical.append(str(col))
    return numeric, categorical


class HurdleWaitingTimeRegressor(RegressorMixin, BaseEstimator):  # type: ignore[misc]
    """Estimate E[Wait|X] as P(Wait > 0|X) multiplied by E[Wait|Wait > 0, X]."""

    def __init__(
        self,
        *,
        categorical_features: list[str],
        numeric_features: list[str],
        classifier_max_iter: int = 250,
        count_max_iter: int = 250,
        classifier_learning_rate: float = 0.05,
        count_learning_rate: float = 0.05,
        classifier_max_leaf_nodes: int = 31,
        count_max_leaf_nodes: int = 31,
        classifier_l2_regularization: float = 0.2,
        count_l2_regularization: float = 0.2,
        random_seed: int = 20260821,
    ) -> None:
        self.categorical_features = categorical_features
        self.numeric_features = numeric_features
        self.classifier_max_iter = classifier_max_iter
        self.count_max_iter = count_max_iter
        self.classifier_learning_rate = classifier_learning_rate
        self.count_learning_rate = count_learning_rate
        self.classifier_max_leaf_nodes = classifier_max_leaf_nodes
        self.count_max_leaf_nodes = count_max_leaf_nodes
        self.classifier_l2_regularization = classifier_l2_regularization
        self.count_l2_regularization = count_l2_regularization
        self.random_seed = random_seed

    def _prepare_data(self, frame: pd.DataFrame) -> pd.DataFrame:
        df = frame[self.numeric_features + self.categorical_features].copy()
        for col in self.numeric_features:
            df[col] = pd.to_numeric(df[col], errors="coerce").astype("float32")
        for col in self.categorical_features:
            df[col] = df[col].astype("string").fillna("__missing__").astype(str)
        return df

    def fit(self, frame: pd.DataFrame, target: NDArray[np.float64]) -> Self:
        """Fit occurrence on every row and severity only on positive-wait rows."""
        self.features_in_ = self.numeric_features + self.categorical_features
        df = self._prepare_data(frame)

        values = np.asarray(target, dtype="float64")

        occurrence = (values > 0).astype("int8")
        positive = occurrence == 1

        self.preprocessor = ColumnTransformer(
            transformers=[
                (
                    "cat",
                    OrdinalEncoder(
                        handle_unknown="use_encoded_value",
                        unknown_value=-1,
                        encoded_missing_value=-1,
                    ),
                    self.categorical_features,
                ),
                ("num", "passthrough", self.numeric_features),
            ]
        )

        X_processed = self.preprocessor.fit_transform(df)
        X_processed = np.asarray(X_processed, dtype="float32")

        new_cat_indices = list(range(len(self.categorical_features)))

        self.occurrence_model_ = HistGradientBoostingClassifier(
            loss="log_loss",
            learning_rate=self.classifier_learning_rate,
            max_iter=self.classifier_max_iter,
            max_leaf_nodes=self.classifier_max_leaf_nodes,
            l2_regularization=self.classifier_l2_regularization,
            early_stopping=False,
            categorical_features=new_cat_indices if new_cat_indices else None,
            class_weight="balanced",  # Wait times > 0 are extremely rare (~1%)
            random_state=self.random_seed,
        )
        self.positive_count_model_ = HistGradientBoostingRegressor(
            loss="squared_error",
            learning_rate=self.count_learning_rate,
            max_iter=self.count_max_iter,
            max_leaf_nodes=self.count_max_leaf_nodes,
            l2_regularization=self.count_l2_regularization,
            early_stopping=False,
            categorical_features=new_cat_indices if new_cat_indices else None,
            random_state=self.random_seed,
        )
        self.occurrence_model_.fit(X_processed, occurrence)
        self.positive_count_model_.fit(X_processed[positive], values[positive])

        self.training_rows_ = len(df)
        self.positive_training_rows_ = int(positive.sum())
        return self

    def _transform(self, frame: pd.DataFrame) -> NDArray[np.float32]:
        df = self._prepare_data(frame)
        X_processed = self.preprocessor.transform(df)
        return np.asarray(X_processed, dtype="float32")

    def predict_nonzero_probability(self, frame: pd.DataFrame) -> NDArray[np.float64]:
        X_processed = self._transform(frame)
        classes = np.asarray(self.occurrence_model_.classes_)
        positive_columns = np.flatnonzero(classes == 1)
        probability = self.occurrence_model_.predict_proba(X_processed)[:, int(positive_columns[0])]
        return cast(
            NDArray[np.float64],
            np.clip(np.asarray(probability, dtype="float64"), 0.0, 1.0),
        )

    def predict_positive_mean(self, frame: pd.DataFrame) -> NDArray[np.float64]:
        X_processed = self._transform(frame)
        prediction = self.positive_count_model_.predict(X_processed)
        return cast(
            NDArray[np.float64],
            np.clip(np.asarray(prediction, dtype="float64"), 0.0, None),
        )

    def predict(self, frame: pd.DataFrame) -> NDArray[np.float64]:
        probability = self.predict_nonzero_probability(frame)
        positive_mean = self.predict_positive_mean(frame)
        return probability * positive_mean


def _binary_stage_metrics(
    truth: NDArray[np.float64], probability: NDArray[np.float64]
) -> dict[str, float]:
    occurrence = (truth > 0).astype("int8")
    clipped = np.clip(probability, 1e-6, 1.0 - 1e-6)
    return {
        "nonzero_prevalence": float(occurrence.mean()),
        "predicted_probability_mean": float(probability.mean()),
        "log_loss": float(log_loss(occurrence, clipped, labels=[0, 1])),
        "brier_score": float(brier_score_loss(occurrence, probability)),
        "average_precision": float(average_precision_score(occurrence, probability)),
        "roc_auc": float(roc_auc_score(occurrence, probability)),
    }


def _metrics(
    truth: NDArray[np.float64], prediction: NDArray[np.float64]
) -> dict[str, float | None]:
    nonzero = truth > 0
    denominator = float(np.abs(truth).sum())
    return {
        "mae": float(mean_absolute_error(truth, prediction)),
        "wape": float(np.abs(truth - prediction).sum() / denominator) if denominator > 0 else None,
        "nonzero_mae": float(mean_absolute_error(truth[nonzero], prediction[nonzero]))
        if bool(nonzero.any())
        else None,
        "prediction_mean": float(prediction.mean()),
        "truth_mean": float(truth.mean()),
    }


def _stage_report(
    model: HurdleWaitingTimeRegressor,
    frame: pd.DataFrame,
) -> dict[str, Any]:
    truth = frame[TARGET].to_numpy(dtype="float64")
    probability = model.predict_nonzero_probability(frame)
    positive_mean = model.predict_positive_mean(frame)
    expected_wait = probability * positive_mean
    positive = truth > 0

    zero_pred = np.zeros_like(truth)

    return {
        "hurdle_expected_wait": _metrics(truth, expected_wait),
        "zero_prediction_baseline_mae": float(mean_absolute_error(truth, zero_pred)),
        "occurrence_classifier": _binary_stage_metrics(truth, probability),
        "positive_wait_regressor": (
            _metrics(truth[positive], positive_mean[positive]) if positive.any() else None
        ),
        "formula_integrity_max_absolute_error": float(
            np.max(np.abs(model.predict(frame) - expected_wait))
        ),
    }


def _portable_artifact_reference(target: Path, artifact_dir: Path) -> str:
    try:
        return Path(os.path.relpath(target.resolve(), start=artifact_dir.resolve())).as_posix()
    except ValueError:
        return target.name


def train_hurdle_waiting_time_model(
    suite_manifest_path: Path,
    output_root: Path,
    model_settings: WaitingTimeTrainingSettings,
    unlock_test: bool = False,
) -> Path:
    """Train a locked-test-safe hurdle candidate for waiting times."""

    suite, readiness = _load_suite(suite_manifest_path)
    train = _load_role(suite, "train")
    if (
        model_settings.maximum_training_rows > 0
        and len(train) > model_settings.maximum_training_rows
    ):
        train = train.sample(
            n=model_settings.maximum_training_rows,
            random_state=model_settings.random_seed,
        ).sort_index()

    validation = _load_role(suite, "validation")
    numeric, categorical = _feature_spec(train)

    model = HurdleWaitingTimeRegressor(
        numeric_features=numeric,
        categorical_features=categorical,
        classifier_max_iter=model_settings.classifier_max_iter,
        count_max_iter=model_settings.count_max_iter,
        classifier_learning_rate=model_settings.classifier_learning_rate,
        count_learning_rate=model_settings.count_learning_rate,
        classifier_max_leaf_nodes=model_settings.classifier_max_leaf_nodes,
        count_max_leaf_nodes=model_settings.count_max_leaf_nodes,
        classifier_l2_regularization=model_settings.classifier_l2_regularization,
        count_l2_regularization=model_settings.count_l2_regularization,
        random_seed=model_settings.random_seed,
    )

    train_y = train[TARGET].to_numpy(dtype="float64")
    model.fit(train, train_y)

    report: dict[str, Any] = {
        "model": "waiting_time_hurdle",
        "algorithm": {
            "occurrence": "HistGradientBoostingClassifier(loss=log_loss, class_weight=balanced)",
            "positive_count": "HistGradientBoostingRegressor(loss=squared_error)",
            "combination": "P(Y>0|X) * E[Y|Y>0,X]",
        },
        "device": "cpu",
        "training_rows": len(train),
        "positive_training_rows": int((train_y > 0).sum()),
        "validation_rows": len(validation),
        "feature_count": len(numeric) + len(categorical),
        "features": {"numeric": numeric, "categorical": categorical},
        "model_settings": asdict(model_settings),
        "validation": _stage_report(model, validation),
        "locked_test_unlocked": unlock_test,
        "data_readiness": readiness["models"]["waiting_time"],
    }

    if unlock_test:
        locked_test = _load_role(suite, "test", unlock_test=unlock_test)
        report["locked_test"] = _stage_report(model, locked_test)

    identity = hashlib.sha256()
    identity.update(suite_manifest_path.read_bytes())
    identity.update(
        json.dumps(
            {
                "model_settings": asdict(model_settings),
                "unlock_test": unlock_test,
            },
            sort_keys=True,
        ).encode("utf-8")
    )
    model_id = f"waiting-time-hurdle-{identity.hexdigest()[:16]}"
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
            "features": {"numeric": numeric, "categorical": categorical},
            "prediction_contract": {
                "occurrence_probability": "predict_nonzero_probability",
                "conditional_positive_mean": "predict_positive_mean",
                "expected_wait": "predict",
            },
        },
        model_path,
    )
    write_manifest(report, incomplete / "evaluation_report.json")
    manifest = {
        "model_id": model_id,
        "model_name": "waiting_time_hurdle",
        "model_version": "v1",
        "created_at": datetime.now(UTC).isoformat(),
        "feature_suite_manifest": _portable_artifact_reference(suite_manifest_path, output_dir),
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
