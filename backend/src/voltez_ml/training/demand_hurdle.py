"""Two-stage hurdle candidate for causal rolling-window demand forecasts."""

from __future__ import annotations

import hashlib
import json
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Self, cast

import joblib  # type: ignore[import-untyped]
import numpy as np
import pandas as pd
from numpy.typing import NDArray
from sklearn.base import BaseEstimator, RegressorMixin  # type: ignore[import-untyped]
from sklearn.ensemble import (  # type: ignore[import-untyped]
    HistGradientBoostingClassifier,
    HistGradientBoostingRegressor,
)
from sklearn.metrics import (  # type: ignore[import-untyped]
    average_precision_score,
    brier_score_loss,
    log_loss,
    roc_auc_score,
)

from voltez_ml.synthetic.io import file_sha256, write_manifest
from voltez_ml.training.demand import (
    TARGET,
    _feature_columns,
    _load_suite,
    _metrics,
    _portable_artifact_reference,
    _sample_training_rows,
)
from voltez_ml.training.demand_window import (
    WINDOW_BASELINE,
    DemandWindowSettings,
    _git_state,
    _window_role,
)


@dataclass(frozen=True)
class HurdleTrainingSettings:
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


class HurdleDemandRegressor(RegressorMixin, BaseEstimator):  # type: ignore[misc]
    """Estimate E[Y|X] as P(Y > 0|X) multiplied by E[Y|Y > 0, X]."""

    def __init__(
        self,
        *,
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
        self.classifier_max_iter = classifier_max_iter
        self.count_max_iter = count_max_iter
        self.classifier_learning_rate = classifier_learning_rate
        self.count_learning_rate = count_learning_rate
        self.classifier_max_leaf_nodes = classifier_max_leaf_nodes
        self.count_max_leaf_nodes = count_max_leaf_nodes
        self.classifier_l2_regularization = classifier_l2_regularization
        self.count_l2_regularization = count_l2_regularization
        self.random_seed = random_seed

    @staticmethod
    def _matrix(features: Any) -> NDArray[np.float32]:
        matrix = np.asarray(features, dtype="float32")
        if matrix.ndim != 2 or matrix.shape[1] == 0:
            raise ValueError("hurdle features must be a non-empty two-dimensional matrix")
        if bool(np.isinf(matrix).any()):
            raise ValueError("hurdle features cannot contain infinite values")
        return cast(NDArray[np.float32], matrix)

    def fit(self, features: Any, target: Any) -> Self:
        """Fit occurrence on every row and severity only on positive-demand rows."""

        matrix = self._matrix(features)
        values = np.asarray(target, dtype="float64")
        if values.ndim != 1 or len(values) != len(matrix):
            raise ValueError("hurdle target must be one-dimensional and match the features")
        if not bool(np.isfinite(values).all()):
            raise ValueError("hurdle target must contain only finite values")
        if bool((values < 0).any()) or not bool(np.allclose(values, np.rint(values))):
            raise ValueError("hurdle target must contain non-negative integer counts")

        occurrence = (values > 0).astype("int8")
        if len(np.unique(occurrence)) != 2:
            raise ValueError("hurdle training requires both zero and positive examples")
        positive = occurrence == 1

        self.occurrence_model_ = HistGradientBoostingClassifier(
            loss="log_loss",
            learning_rate=self.classifier_learning_rate,
            max_iter=self.classifier_max_iter,
            max_leaf_nodes=self.classifier_max_leaf_nodes,
            l2_regularization=self.classifier_l2_regularization,
            early_stopping=False,
            random_state=self.random_seed,
        )
        self.positive_count_model_ = HistGradientBoostingRegressor(
            loss="poisson",
            learning_rate=self.count_learning_rate,
            max_iter=self.count_max_iter,
            max_leaf_nodes=self.count_max_leaf_nodes,
            l2_regularization=self.count_l2_regularization,
            early_stopping=False,
            random_state=self.random_seed,
        )
        self.occurrence_model_.fit(matrix, occurrence)
        self.positive_count_model_.fit(matrix[positive], values[positive])
        self.n_features_in_ = matrix.shape[1]
        self.training_rows_ = len(matrix)
        self.positive_training_rows_ = int(positive.sum())
        return self

    def _checked_matrix(self, features: Any) -> NDArray[np.float32]:
        if not hasattr(self, "occurrence_model_") or not hasattr(self, "positive_count_model_"):
            raise ValueError("hurdle model must be fitted before prediction")
        matrix = self._matrix(features)
        if matrix.shape[1] != self.n_features_in_:
            raise ValueError(f"expected {self.n_features_in_} features, received {matrix.shape[1]}")
        return matrix

    def predict_nonzero_probability(self, features: Any) -> NDArray[np.float64]:
        """Return the classifier's probability that the future count is non-zero."""

        matrix = self._checked_matrix(features)
        classes = np.asarray(self.occurrence_model_.classes_)
        positive_columns = np.flatnonzero(classes == 1)
        if len(positive_columns) != 1:
            raise ValueError("occurrence classifier does not contain the positive class")
        probability = self.occurrence_model_.predict_proba(matrix)[:, int(positive_columns[0])]
        return cast(
            NDArray[np.float64],
            np.clip(np.asarray(probability, dtype="float64"), 0.0, 1.0),
        )

    def predict_positive_mean(self, features: Any) -> NDArray[np.float64]:
        """Return E[Y|Y>0,X], constrained to the positive-count support."""

        matrix = self._checked_matrix(features)
        prediction = self.positive_count_model_.predict(matrix)
        return cast(
            NDArray[np.float64],
            np.clip(np.asarray(prediction, dtype="float64"), 1.0, None),
        )

    def predict(self, features: Any) -> NDArray[np.float64]:
        """Return expected demand without imposing an arbitrary class threshold."""

        probability = self.predict_nonzero_probability(features)
        positive_mean = self.predict_positive_mean(features)
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


def _stage_report(
    model: HurdleDemandRegressor,
    frame: pd.DataFrame,
    features: list[str],
) -> dict[str, Any]:
    matrix = frame[features].astype("float32")
    truth = frame[TARGET].to_numpy(dtype="float64")
    probability = model.predict_nonzero_probability(matrix)
    positive_mean = model.predict_positive_mean(matrix)
    expected_demand = probability * positive_mean
    positive = truth > 0
    return {
        "hurdle_expected_demand": _metrics(truth, expected_demand),
        "occurrence_classifier": _binary_stage_metrics(truth, probability),
        "positive_count_regressor": _metrics(truth[positive], positive_mean[positive]),
        "formula_integrity_max_absolute_error": float(
            np.max(np.abs(model.predict(matrix) - expected_demand))
        ),
    }


def train_hurdle_demand_window_model(
    suite_manifest_path: Path,
    output_root: Path,
    model_settings: HurdleTrainingSettings,
    window_settings: DemandWindowSettings,
    unlock_test: bool = False,
) -> Path:
    """Train a locked-test-safe hurdle candidate on the same window as the benchmark."""

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
        raise ValueError(f"validation partition is missing features: {sorted(missing_validation)}")

    model = HurdleDemandRegressor(
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
    model.fit(
        train[features].astype("float32"),
        train[TARGET].to_numpy(dtype="float64"),
    )
    validation_y = validation[TARGET].to_numpy(dtype="float64")
    report: dict[str, Any] = {
        "model": "demand_forecasting_hurdle_rolling_window",
        "algorithm": {
            "occurrence": "HistGradientBoostingClassifier(loss=log_loss)",
            "positive_count": "HistGradientBoostingRegressor(loss=poisson)",
            "combination": "P(Y>0|X) * E[Y|Y>0,X]",
        },
        "device": "cpu",
        "hardware_note": "scikit-learn histogram boosting uses the Apple M4 CPU, not MPS",
        "training_rows": len(train),
        "positive_training_rows": int((train[TARGET] > 0).sum()),
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
            **_stage_report(model, validation, features),
        },
        "locked_test_unlocked": unlock_test,
        "data_readiness": readiness["models"]["demand"],
    }
    if unlock_test:
        locked_test = _window_role(suite, "test", window_settings)
        locked_test_y = locked_test[TARGET].to_numpy(dtype="float64")
        report["locked_test"] = {
            "seasonal_naive": _metrics(
                locked_test_y,
                locked_test[WINDOW_BASELINE].to_numpy(dtype="float64"),
            ),
            **_stage_report(model, locked_test, features),
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
    model_id = f"demand-window-{window_settings.window_minutes}m-hurdle-{identity.hexdigest()[:16]}"
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
            "prediction_contract": {
                "occurrence_probability": "predict_nonzero_probability",
                "conditional_positive_mean": "predict_positive_mean",
                "expected_demand": "predict",
            },
        },
        model_path,
    )
    write_manifest(report, incomplete / "evaluation_report.json")
    manifest = {
        "model_id": model_id,
        "model_name": "demand_forecasting_hurdle_rolling_window",
        "model_version": "v1-experiment",
        "created_at": datetime.now(UTC).isoformat(),
        "feature_suite_manifest": _portable_artifact_reference(suite_manifest_path, output_dir),
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
