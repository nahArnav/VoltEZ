"""FastAPI-ready Model 3 loading, feature validation, OOD handling, and fallback."""

from __future__ import annotations

import json
import warnings
from datetime import datetime
from pathlib import Path
from typing import Any, Literal

import joblib  # type: ignore[import-untyped]
import numpy as np
import pandas as pd
from pydantic import BaseModel, ConfigDict, Field, field_validator

from voltez_ml.synthetic.io import file_sha256, write_manifest
from voltez_ml.training.waiting_time import _load_role, _load_suite

BINARY_FEATURES = {
    "target_is_weekend",
    "cold_start",
    "reliability_cold_start",
    "status_expired",
}


class WaitingTimeInputError(ValueError):
    """Raised when an application request violates the frozen feature contract."""


class WaitingTimeFeatureRule(BaseModel):
    model_config = ConfigDict(extra="forbid")

    kind: Literal["binary", "rate", "periodic", "nonnegative", "continuous", "categorical"]
    allow_missing: bool
    train_min: float | None = None
    train_max: float | None = None
    soft_min: float | None = None
    soft_max: float | None = None
    median: float | None = None
    hard_min: float | None = None
    hard_max: float | None = None
    allowed_values: list[str] = Field(default_factory=list)


class WaitingTimeOODPolicy(BaseModel):
    model_config = ConfigDict(extra="forbid")
    max_outside_training_range: int = Field(default=3, ge=0)
    max_outside_soft_range: int = Field(default=8, ge=0)
    action: Literal["zero_wait_fallback"] = "zero_wait_fallback"


class WaitingTimeFeatureContract(BaseModel):
    model_config = ConfigDict(extra="forbid")

    schema_version: Literal["voltez-waiting-time-serving-v1"]
    model_id: str
    model_artifact_sha256: str
    feature_suite_manifest_sha256: str
    feature_order: list[str]
    numeric_features: list[str]
    categorical_features: list[str]
    features: dict[str, WaitingTimeFeatureRule]
    timezone: str
    training_rows: int = Field(gt=0)
    ood_policy: WaitingTimeOODPolicy


FeatureValue = float | int | str | None


class WaitingTimeFeatureRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)

    port_id: str = Field(min_length=1)
    prediction_origin: datetime
    target_time: datetime
    features: dict[str, FeatureValue]

    @field_validator("prediction_origin", "target_time")
    @classmethod
    def require_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("timestamps must include a timezone")
        return value


class WaitingTimePredictionResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    model_id: str
    port_id: str
    prediction_origin: datetime
    target_time: datetime
    expected_wait_minutes: float = Field(ge=0)
    nonzero_wait_probability: float = Field(ge=0, le=1)
    quality: Literal["in_domain", "warning", "fallback"]
    used_fallback: bool
    warnings: list[str]
    outside_training_range: list[str]


def _load_artifact(artifact_dir: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    manifest = json.loads((artifact_dir / "manifest.json").read_text("utf-8"))
    model_path = artifact_dir / str(manifest["artifact"]["path"])
    if file_sha256(model_path) != manifest["artifact"]["sha256"]:
        raise ValueError("model artifact hash does not match its manifest")
    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore",
            message="Setting the shape on a NumPy array has been deprecated.*",
            category=DeprecationWarning,
        )
        payload = joblib.load(model_path)
    required = {
        "model",
        "features",
        "prediction_contract",
    }
    if not isinstance(payload, dict) or not required.issubset(payload):
        raise ValueError("waiting time artifact payload is incomplete")
    return manifest, payload


def build_waiting_time_feature_contract(
    artifact_dir: Path,
    suite_manifest_path: Path,
    output_path: Path,
) -> Path:
    """Build the serving contract from training worlds only."""

    manifest, payload = _load_artifact(artifact_dir)
    if file_sha256(suite_manifest_path) != manifest["feature_suite_manifest_sha256"]:
        raise ValueError("feature suite hash does not match the artifact")
    suite, _ = _load_suite(suite_manifest_path)
    train = _load_role(suite, "train")

    spec = payload["features"]
    numeric = [str(value) for value in spec["numeric"]]
    categorical = [str(value) for value in spec["categorical"]]
    feature_order = numeric + categorical
    missing = set(feature_order) - set(train.columns)
    if missing:
        raise ValueError(f"training role is missing model features: {sorted(missing)}")

    rules: dict[str, dict[str, Any]] = {}
    for feature in numeric:
        series = pd.to_numeric(train[feature], errors="coerce")
        finite = series[np.isfinite(series)]
        if finite.empty:
            raise ValueError(f"feature {feature} has no finite training values")
        minimum = float(finite.min())
        kind = "continuous"
        if minimum >= 0:
            kind = "nonnegative"
        if feature in BINARY_FEATURES:
            kind = "binary"
        rules[feature] = {
            "kind": kind,
            "allow_missing": bool(series.isna().any()),
            "train_min": minimum,
            "train_max": float(finite.max()),
            "soft_min": float(finite.quantile(0.001)),
            "soft_max": float(finite.quantile(0.999)),
            "median": float(finite.median()),
            "hard_min": None,
            "hard_max": None,
            "allowed_values": [],
        }
    for feature in categorical:
        values = train[feature].astype("string")
        rules[feature] = {
            "kind": "categorical",
            "allow_missing": bool(values.isna().any()),
            "allowed_values": sorted(str(value) for value in values.dropna().unique()),
        }

    origins = pd.to_datetime(train["prediction_origin"])
    contract = {
        "schema_version": "voltez-waiting-time-serving-v1",
        "model_id": manifest["model_id"],
        "model_artifact_sha256": manifest["artifact"]["sha256"],
        "feature_suite_manifest_sha256": manifest["feature_suite_manifest_sha256"],
        "feature_order": feature_order,
        "numeric_features": numeric,
        "categorical_features": categorical,
        "features": rules,
        "timezone": str(origins.dt.tz),
        "training_rows": len(train),
        "ood_policy": {
            "max_outside_training_range": 3,
            "max_outside_soft_range": 8,
            "action": "zero_wait_fallback",
        },
    }

    WaitingTimeFeatureContract.model_validate(contract)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    write_manifest(contract, output_path)
    return output_path
