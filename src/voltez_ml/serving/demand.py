"""FastAPI-ready Model 1 loading, feature validation, OOD handling, and fallback."""

from __future__ import annotations

import json
import math
import warnings
from collections import Counter
from collections.abc import Mapping, Sequence
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Literal, Self
from zoneinfo import ZoneInfo

import joblib  # type: ignore[import-untyped]
import numpy as np
import pandas as pd
from pydantic import BaseModel, ConfigDict, Field, field_validator

from voltez_ml.synthetic.io import file_sha256, write_manifest
from voltez_ml.training.demand import TARGET, _load_suite
from voltez_ml.training.demand_window import DemandWindowSettings, _window_role

ZONE_PREFIX = "zone_type_"
BINARY_FEATURES = {
    "missing_lag_yesterday",
    "missing_lag_last_week",
    "missing_target_lag_yesterday",
    "missing_target_lag_last_week",
    "missing_same_window_yesterday",
    "missing_same_window_last_week",
    "target_is_weekend",
}
RATE_FEATURES = {"occupancy_lag_1", "no_candidate_rate_prior_hour"}
PERIODIC_FEATURES = {
    "target_hour_sin",
    "target_hour_cos",
    "target_day_sin",
    "target_day_cos",
}
FALLBACK_FEATURES = {
    "request_sum_same_window_last_week",
    "request_sum_same_window_yesterday",
    "missing_same_window_last_week",
    "missing_same_window_yesterday",
    "request_ewm_prior",
}


class DemandInputError(ValueError):
    """Raised when an application request violates the frozen feature contract."""


class FeatureRule(BaseModel):
    """Observed distribution plus semantic limits for one model feature."""

    model_config = ConfigDict(extra="forbid")

    kind: str
    train_min: float
    train_max: float
    soft_min: float
    soft_max: float
    median: float
    missing_rate: float
    allow_missing: bool
    hard_min: float | None = None
    hard_max: float | None = None


class OODPolicy(BaseModel):
    """Rules deciding whether valid-but-shifted input uses a safe fallback."""

    model_config = ConfigDict(extra="forbid")

    max_outside_training_range: int = 5
    max_outside_soft_range: int = 10
    action: Literal["seasonal_fallback"] = "seasonal_fallback"


class DemandFeatureContract(BaseModel):
    """Frozen ordered feature schema consumed by the inference service."""

    model_config = ConfigDict(extra="forbid")

    schema_version: Literal["voltez-demand-serving-v1"]
    model_id: str
    model_artifact_sha256: str
    feature_suite_manifest_sha256: str
    feature_order: list[str]
    features: dict[str, FeatureRule]
    target_spec: dict[str, int | str]
    timezone: str
    training_rows: int
    target_distribution: dict[str, float]
    ood_policy: OODPolicy
    fallback_feature_order: list[str]


class DemandFeatureRequest(BaseModel):
    """Request body that a FastAPI endpoint can accept directly."""

    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)

    zone_id: str = Field(min_length=1)
    prediction_origin: datetime
    features: dict[str, float | None]

    @field_validator("prediction_origin")
    @classmethod
    def require_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("prediction_origin must include a timezone")
        return value


class DemandPredictionResponse(BaseModel):
    """Stable JSON response for APIs, dashboards, and route ranking."""

    model_config = ConfigDict(extra="forbid")

    model_id: str
    zone_id: str
    prediction_origin: datetime
    target_window_start: datetime
    target_window_end: datetime
    expected_requests: float = Field(ge=0)
    rounded_requests: int = Field(ge=0)
    quality: Literal["in_domain", "warning", "fallback"]
    used_fallback: bool
    warnings: list[str]
    outside_training_range: list[str]


def _load_artifact(artifact_dir: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    manifest_path = artifact_dir / "manifest.json"
    manifest = json.loads(manifest_path.read_text("utf-8"))
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
    if not isinstance(payload, dict) or "model" not in payload or "features" not in payload:
        raise ValueError("model artifact payload is missing its estimator or feature order")
    return manifest, payload


def _feature_kind(
    name: str, minimum: float, maximum: float
) -> tuple[str, float | None, float | None]:
    if (
        name in BINARY_FEATURES
        or name.startswith(ZONE_PREFIX)
        or (name.startswith("context_event_") and name != "context_event_count")
    ):
        return "binary", 0.0, 1.0
    if name in RATE_FEATURES:
        return "rate", 0.0, 1.0
    if name in PERIODIC_FEATURES:
        return "periodic", -1.0, 1.0
    if name == "centroid_latitude":
        return "pune_latitude", minimum - 0.05, maximum + 0.05
    if name == "centroid_longitude":
        return "pune_longitude", minimum - 0.05, maximum + 0.05
    if minimum >= 0:
        return "nonnegative", 0.0, None
    return "continuous", None, None


def build_demand_feature_contract(
    artifact_dir: Path,
    suite_manifest_path: Path,
    output_path: Path,
) -> Path:
    """Derive a serving contract from training rows only; never load the test role."""

    artifact_manifest, payload = _load_artifact(artifact_dir)
    if file_sha256(suite_manifest_path) != artifact_manifest["feature_suite_manifest_sha256"]:
        raise ValueError("feature suite hash does not match the selected model artifact")
    features = [str(value) for value in payload["features"]]
    target_spec = dict(payload.get("target_spec", {"kind": "point_count"}))
    if target_spec.get("kind") != "rolling_sum":
        raise ValueError("Model 1 serving currently requires a rolling-window target")
    window_settings = DemandWindowSettings(
        window_minutes=int(target_spec["window_minutes"]),
        forecast_lead_minutes=int(target_spec["forecast_lead_minutes"]),
        bucket_minutes=int(target_spec["bucket_minutes"]),
    )
    suite, _ = _load_suite(suite_manifest_path)
    train = _window_role(suite, "train", window_settings)
    missing = set(features) - set(train.columns)
    if missing:
        raise ValueError(f"training role is missing model features: {sorted(missing)}")

    rules: dict[str, dict[str, float | str | bool | None]] = {}
    for feature in features:
        series = pd.to_numeric(train[feature], errors="coerce")
        finite = series[np.isfinite(series)]
        if finite.empty:
            raise ValueError(f"feature {feature} has no finite training values")
        minimum = float(finite.min())
        maximum = float(finite.max())
        kind, hard_min, hard_max = _feature_kind(feature, minimum, maximum)
        rules[feature] = {
            "kind": kind,
            "train_min": minimum,
            "train_max": maximum,
            "soft_min": float(finite.quantile(0.001)),
            "soft_max": float(finite.quantile(0.999)),
            "median": float(finite.median()),
            "missing_rate": float(series.isna().mean()),
            "allow_missing": bool(series.isna().any()),
            "hard_min": hard_min,
            "hard_max": hard_max,
        }

    origins = pd.to_datetime(train["prediction_origin"])
    timezone = str(origins.dt.tz)
    target = train[TARGET].to_numpy(dtype="float64")
    contract = {
        "schema_version": "voltez-demand-serving-v1",
        "model_id": artifact_manifest["model_id"],
        "model_artifact_sha256": artifact_manifest["artifact"]["sha256"],
        "feature_suite_manifest_sha256": artifact_manifest["feature_suite_manifest_sha256"],
        "feature_order": features,
        "features": rules,
        "target_spec": target_spec,
        "timezone": timezone,
        "training_rows": len(train),
        "target_distribution": {
            "min": float(target.min()),
            "max": float(target.max()),
            "mean": float(target.mean()),
            "zero_rate": float((target == 0).mean()),
            "p99": float(np.quantile(target, 0.99)),
        },
        "ood_policy": {
            "max_outside_training_range": 5,
            "max_outside_soft_range": 10,
            "action": "seasonal_fallback",
        },
        "fallback_feature_order": sorted(FALLBACK_FEATURES),
    }
    DemandFeatureContract.model_validate(contract)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    write_manifest(contract, output_path)
    return output_path


class _PreparedRequest(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)

    request: DemandFeatureRequest
    row: list[float]
    warnings: list[str]
    outside_training_range: list[str]
    use_fallback: bool


class DemandPredictor:
    """Load a hashed artifact once and apply domain-aware predictions repeatedly."""

    def __init__(
        self,
        *,
        model: Any,
        artifact_manifest: Mapping[str, Any],
        contract: DemandFeatureContract,
    ) -> None:
        self.model = model
        self.artifact_manifest = dict(artifact_manifest)
        self.contract = contract
        self.timezone = ZoneInfo(contract.timezone)

    @classmethod
    def from_artifact(cls, artifact_dir: Path, contract_path: Path) -> Self:
        manifest, payload = _load_artifact(artifact_dir)
        contract = DemandFeatureContract.model_validate_json(contract_path.read_text("utf-8"))
        if contract.model_id != manifest["model_id"]:
            raise ValueError("feature contract belongs to a different model id")
        if contract.model_artifact_sha256 != manifest["artifact"]["sha256"]:
            raise ValueError("feature contract belongs to a different model artifact")
        artifact_features = [str(value) for value in payload["features"]]
        if contract.feature_order != artifact_features:
            raise ValueError("feature contract order differs from the artifact")
        return cls(
            model=payload["model"],
            artifact_manifest=manifest,
            contract=contract,
        )

    def _calendar_violations(self, request: DemandFeatureRequest) -> list[str]:
        local_origin = request.prediction_origin.astimezone(self.timezone)
        lead = int(self.contract.target_spec["forecast_lead_minutes"])
        target = local_origin + timedelta(minutes=lead)
        target_hour = target.hour + target.minute / 60
        target_day = target.weekday()
        expected = {
            "target_hour_sin": math.sin(2 * math.pi * target_hour / 24),
            "target_hour_cos": math.cos(2 * math.pi * target_hour / 24),
            "target_day_sin": math.sin(2 * math.pi * target_day / 7),
            "target_day_cos": math.cos(2 * math.pi * target_day / 7),
            "target_is_weekend": float(target_day >= 5),
        }
        violations: list[str] = []
        for feature, expected_value in expected.items():
            observed = request.features.get(feature)
            if observed is None or abs(float(observed) - expected_value) > 1e-4:
                violations.append(f"{feature} disagrees with prediction_origin")
        return violations

    def _prepare(self, request: DemandFeatureRequest) -> _PreparedRequest:
        expected = set(self.contract.feature_order)
        observed = set(request.features)
        missing = sorted(expected - observed)
        extra = sorted(observed - expected)
        if missing or extra:
            raise DemandInputError(f"feature schema mismatch; missing={missing}, extra={extra}")

        row: list[float] = []
        hard_violations: list[str] = self._calendar_violations(request)
        outside_training: list[str] = []
        outside_soft: list[str] = []
        for feature in self.contract.feature_order:
            value = request.features[feature]
            rule = self.contract.features[feature]
            if value is None:
                if not rule.allow_missing:
                    hard_violations.append(f"{feature} cannot be missing")
                row.append(float("nan"))
                continue
            number = float(value)
            if not math.isfinite(number):
                hard_violations.append(f"{feature} must be finite or null")
            if rule.hard_min is not None and number < rule.hard_min - 1e-6:
                hard_violations.append(f"{feature} is below its semantic minimum")
            if rule.hard_max is not None and number > rule.hard_max + 1e-6:
                hard_violations.append(f"{feature} is above its semantic maximum")
            if number < rule.train_min or number > rule.train_max:
                outside_training.append(feature)
            if number < rule.soft_min or number > rule.soft_max:
                outside_soft.append(feature)
            row.append(number)

        zone_values = [
            request.features[name]
            for name in self.contract.feature_order
            if name.startswith(ZONE_PREFIX)
        ]
        if zone_values and (
            any(value is None for value in zone_values)
            or abs(sum(float(value) for value in zone_values if value is not None) - 1.0) > 1e-6
        ):
            hard_violations.append("exactly one zone_type feature must equal one")
        if hard_violations:
            raise DemandInputError("; ".join(sorted(set(hard_violations))))

        policy = self.contract.ood_policy
        use_fallback = (
            len(outside_training) > policy.max_outside_training_range
            or len(outside_soft) > policy.max_outside_soft_range
        )
        messages: list[str] = []
        if outside_training:
            messages.append(f"{len(outside_training)} feature(s) are outside the training range")
        elif outside_soft:
            messages.append(f"{len(outside_soft)} feature(s) are in valid but rare training tails")
        if use_fallback:
            messages.append("OOD threshold exceeded; seasonal fallback used")
        return _PreparedRequest(
            request=request,
            row=row,
            warnings=messages,
            outside_training_range=sorted(outside_training),
            use_fallback=use_fallback,
        )

    def _fallback(self, features: Mapping[str, float | None]) -> float:
        if float(features["missing_same_window_last_week"] or 0.0) < 0.5:
            value = features["request_sum_same_window_last_week"]
            if value is not None:
                return max(float(value), 0.0)
        if float(features["missing_same_window_yesterday"] or 0.0) < 0.5:
            value = features["request_sum_same_window_yesterday"]
            if value is not None:
                return max(float(value), 0.0)
        bucket_count = int(self.contract.target_spec["window_minutes"]) // int(
            self.contract.target_spec["bucket_minutes"]
        )
        return max(float(features["request_ewm_prior"] or 0.0) * bucket_count, 0.0)

    def predict_batch(
        self, requests: Sequence[DemandFeatureRequest]
    ) -> list[DemandPredictionResponse]:
        if not requests:
            return []
        prepared = [self._prepare(request) for request in requests]
        model_indices = [index for index, value in enumerate(prepared) if not value.use_fallback]
        model_predictions: dict[int, float] = {}
        if model_indices:
            matrix = pd.DataFrame(
                [prepared[index].row for index in model_indices],
                columns=self.contract.feature_order,
                dtype="float32",
            )
            prediction = np.clip(np.asarray(self.model.predict(matrix), dtype="float64"), 0.0, None)
            if len(prediction) != len(model_indices) or not bool(np.isfinite(prediction).all()):
                raise RuntimeError("model returned invalid demand predictions")
            model_predictions = dict(zip(model_indices, prediction, strict=True))

        responses: list[DemandPredictionResponse] = []
        lead = int(self.contract.target_spec["forecast_lead_minutes"])
        window = int(self.contract.target_spec["window_minutes"])
        for index, value in enumerate(prepared):
            request = value.request
            target_start = request.prediction_origin + timedelta(minutes=lead)
            expected_requests = (
                self._fallback(request.features) if value.use_fallback else model_predictions[index]
            )
            quality: Literal["in_domain", "warning", "fallback"] = (
                "fallback" if value.use_fallback else "warning" if value.warnings else "in_domain"
            )
            responses.append(
                DemandPredictionResponse(
                    model_id=self.contract.model_id,
                    zone_id=request.zone_id,
                    prediction_origin=request.prediction_origin,
                    target_window_start=target_start,
                    target_window_end=target_start + timedelta(minutes=window),
                    expected_requests=float(expected_requests),
                    rounded_requests=int(math.floor(expected_requests + 0.5)),
                    quality=quality,
                    used_fallback=value.use_fallback,
                    warnings=value.warnings,
                    outside_training_range=value.outside_training_range,
                )
            )
        return responses

    def predict(self, request: DemandFeatureRequest) -> DemandPredictionResponse:
        return self.predict_batch([request])[0]


def requests_from_frame(
    frame: pd.DataFrame,
    feature_order: Sequence[str],
) -> list[DemandFeatureRequest]:
    """Convert audited feature rows into the same DTO used by FastAPI."""

    requests: list[DemandFeatureRequest] = []
    for _, row in frame.iterrows():
        values = {
            feature: None if pd.isna(row[feature]) else float(row[feature])
            for feature in feature_order
        }
        origin = pd.Timestamp(row["prediction_origin"])
        requests.append(
            DemandFeatureRequest(
                zone_id=str(row["zone_id"]),
                prediction_origin=origin.to_pydatetime(),
                features=values,
            )
        )
    return requests


def quality_counts(responses: Sequence[DemandPredictionResponse]) -> dict[str, int]:
    """Stable counts used by audits and production monitoring."""

    return dict(sorted(Counter(response.quality for response in responses).items()))
