"""FastAPI-ready Model 4 loading, validation, abstention, and prediction."""

from __future__ import annotations

import json
import math
import warnings
from collections.abc import Mapping, Sequence
from datetime import datetime
from pathlib import Path
from typing import Any, Literal, Self
from zoneinfo import ZoneInfo

import joblib  # type: ignore[import-untyped]
import numpy as np
import pandas as pd
from pydantic import BaseModel, ConfigDict, Field, field_validator

from voltez_ml.synthetic.io import file_sha256, write_manifest
from voltez_ml.training.reliability import _load_role, _load_suite

BINARY_FEATURES = {
    "target_is_weekend",
    "cold_start",
    "reliability_cold_start",
    "status_expired",
}
RATE_FEATURES = {
    "smoothed_reliability",
    "smoothed_charger_reliability",
    "latest_status_confidence",
    "recent_zone_occupancy_mean_1h",
}
PERIODIC_FEATURES = {
    "target_hour_sin",
    "target_hour_cos",
    "target_day_sin",
    "target_day_cos",
}


class ReliabilityInputError(ValueError):
    """Raised when an application request violates the frozen feature contract."""


class ReliabilityFeatureRule(BaseModel):
    """Training distribution and semantic rules for one Model 4 feature."""

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


class ReliabilityOODPolicy(BaseModel):
    """Conditions under which Model 4 must return unknown instead of guessing."""

    model_config = ConfigDict(extra="forbid")

    max_outside_training_range: int = Field(default=3, ge=0)
    max_outside_soft_range: int = Field(default=8, ge=0)
    unknown_category_action: Literal["abstain"] = "abstain"
    missing_status_action: Literal["abstain"] = "abstain"


class ReliabilityFeatureContract(BaseModel):
    """Frozen ordered schema used by the backend feature service."""

    model_config = ConfigDict(extra="forbid")

    schema_version: Literal["voltez-reliability-serving-v1"]
    model_id: str
    model_artifact_sha256: str
    feature_suite_manifest_sha256: str
    feature_order: list[str]
    numeric_features: list[str]
    categorical_features: list[str]
    features: dict[str, ReliabilityFeatureRule]
    thresholds: dict[str, float]
    timezone: str
    training_rows: int = Field(gt=0)
    ood_policy: ReliabilityOODPolicy
    hard_gates: list[str]


FeatureValue = float | int | str | None


class ReliabilityFeatureRequest(BaseModel):
    """Internal request built by FastAPI after deterministic eligibility checks."""

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


class ReliabilityPredictionResponse(BaseModel):
    """Stable response consumed by charger search and route ranking."""

    model_config = ConfigDict(extra="forbid")

    model_id: str
    port_id: str
    prediction_origin: datetime
    target_time: datetime
    decision: Literal["reliable", "unreliable", "unknown"]
    probability_unreliable: float | None = Field(default=None, ge=0, le=1)
    quality: Literal["in_domain", "warning", "abstained"]
    warnings: list[str]
    outside_training_range: list[str]


class _PreparedReliabilityRequest(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)

    request: ReliabilityFeatureRequest
    row: dict[str, float | str]
    warnings: list[str]
    outside_training_range: list[str]
    must_abstain: bool


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
        "base_model",
        "calibrator",
        "feature_spec",
        "positive_class",
        "thresholds",
        "missing_status_policy",
    }
    if not isinstance(payload, dict) or not required.issubset(payload):
        raise ValueError("reliability artifact payload is incomplete")
    if payload["positive_class"] != "unreliable":
        raise ValueError("reliability artifact has an unexpected positive class")
    if payload["missing_status_policy"] != "unknown":
        raise ValueError("reliability artifact must abstain when status is missing")
    return manifest, payload


def _numeric_kind(name: str, minimum: float) -> tuple[str, float | None, float | None]:
    if name in BINARY_FEATURES:
        return "binary", 0.0, 1.0
    if name in RATE_FEATURES:
        return "rate", 0.0, 1.0
    if name in PERIODIC_FEATURES:
        return "periodic", -1.0, 1.0
    if minimum >= 0:
        return "nonnegative", 0.0, None
    return "continuous", None, None


def build_reliability_feature_contract(
    artifact_dir: Path,
    suite_manifest_path: Path,
    output_path: Path,
) -> Path:
    """Build the serving contract from training worlds only; never load locked test."""

    manifest, payload = _load_artifact(artifact_dir)
    if file_sha256(suite_manifest_path) != manifest["feature_suite_manifest_sha256"]:
        raise ValueError("feature suite hash does not match the reliability artifact")
    suite, _ = _load_suite(suite_manifest_path)
    train = _load_role(suite, "train")
    spec = payload["feature_spec"]
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
        kind, hard_min, hard_max = _numeric_kind(feature, minimum)
        rules[feature] = {
            "kind": kind,
            "allow_missing": bool(series.isna().any()),
            "train_min": minimum,
            "train_max": float(finite.max()),
            "soft_min": float(finite.quantile(0.001)),
            "soft_max": float(finite.quantile(0.999)),
            "median": float(finite.median()),
            "hard_min": hard_min,
            "hard_max": hard_max,
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
    thresholds = payload["thresholds"]
    contract = {
        "schema_version": "voltez-reliability-serving-v1",
        "model_id": manifest["model_id"],
        "model_artifact_sha256": manifest["artifact"]["sha256"],
        "feature_suite_manifest_sha256": manifest["feature_suite_manifest_sha256"],
        "feature_order": feature_order,
        "numeric_features": numeric,
        "categorical_features": categorical,
        "features": rules,
        "thresholds": {
            "reliable_max_probability_unreliable": float(
                thresholds["reliable_max_probability_unreliable"]
            ),
            "unreliable_min_probability_unreliable": float(
                thresholds["unreliable_min_probability_unreliable"]
            ),
        },
        "timezone": str(origins.dt.tz),
        "training_rows": len(train),
        "ood_policy": {
            "max_outside_training_range": 3,
            "max_outside_soft_range": 8,
            "unknown_category_action": "abstain",
            "missing_status_action": "abstain",
        },
        "hard_gates": [
            "connector compatibility",
            "business and host access",
            "approved reliability window",
            "known active fault or maintenance",
            "confirmed overlapping booking",
            "verification and suspension policy",
        ],
    }
    ReliabilityFeatureContract.model_validate(contract)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    write_manifest(contract, output_path)
    return output_path


class ReliabilityPredictor:
    """Load Model 4 once and make safe, calibrated, three-state decisions."""

    def __init__(
        self,
        *,
        base_model: Any,
        calibrator: Any,
        artifact_manifest: Mapping[str, Any],
        contract: ReliabilityFeatureContract,
    ) -> None:
        self.base_model = base_model
        self.calibrator = calibrator
        self.artifact_manifest = dict(artifact_manifest)
        self.contract = contract
        self.timezone = ZoneInfo(contract.timezone)

    @classmethod
    def from_artifact(cls, artifact_dir: Path, contract_path: Path) -> Self:
        manifest, payload = _load_artifact(artifact_dir)
        contract = ReliabilityFeatureContract.model_validate_json(
            contract_path.read_text("utf-8")
        )
        if contract.model_id != manifest["model_id"]:
            raise ValueError("feature contract belongs to a different model id")
        if contract.model_artifact_sha256 != manifest["artifact"]["sha256"]:
            raise ValueError("feature contract belongs to a different model artifact")
        spec = payload["feature_spec"]
        artifact_order = [*spec["numeric"], *spec["categorical"]]
        if contract.feature_order != artifact_order:
            raise ValueError("feature contract order differs from the artifact")
        return cls(
            base_model=payload["base_model"],
            calibrator=payload["calibrator"],
            artifact_manifest=manifest,
            contract=contract,
        )

    def _calendar_violations(self, request: ReliabilityFeatureRequest) -> list[str]:
        target = request.target_time.astimezone(self.timezone)
        # The training feature builder intentionally encodes calendar time to minute precision.
        target_hour = target.hour + target.minute / 60
        target_day = target.weekday()
        expected = {
            "eta_minutes": (request.target_time - request.prediction_origin).total_seconds() / 60,
            "target_hour_sin": math.sin(2 * math.pi * target_hour / 24),
            "target_hour_cos": math.cos(2 * math.pi * target_hour / 24),
            "target_day_sin": math.sin(2 * math.pi * target_day / 7),
            "target_day_cos": math.cos(2 * math.pi * target_day / 7),
            "target_is_weekend": float(target_day >= 5),
        }
        violations: list[str] = []
        for feature, expected_value in expected.items():
            observed = request.features.get(feature)
            tolerance = 0.1 if feature == "eta_minutes" else 1e-4
            if not isinstance(observed, (int, float)) or isinstance(observed, bool):
                violations.append(f"{feature} must be numeric")
            elif abs(float(observed) - expected_value) > tolerance:
                violations.append(f"{feature} disagrees with request timestamps")
        if request.target_time <= request.prediction_origin:
            violations.append("target_time must be after prediction_origin")
        return violations

    def _prepare(self, request: ReliabilityFeatureRequest) -> _PreparedReliabilityRequest:
        expected = set(self.contract.feature_order)
        observed = set(request.features)
        missing = sorted(expected - observed)
        extra = sorted(observed - expected)
        if missing or extra:
            raise ReliabilityInputError(
                f"feature schema mismatch; missing={missing}, extra={extra}"
            )

        row: dict[str, float | str] = {}
        hard_violations = self._calendar_violations(request)
        outside_training: list[str] = []
        outside_soft: list[str] = []
        unknown_categories: list[str] = []
        missing_status = False
        for feature in self.contract.feature_order:
            value = request.features[feature]
            rule = self.contract.features[feature]
            if rule.kind == "categorical":
                text = "__missing__" if value is None else str(value)
                if value is None and not rule.allow_missing:
                    hard_violations.append(f"{feature} cannot be missing")
                if text not in rule.allowed_values:
                    unknown_categories.append(feature)
                if feature == "latest_status" and text in {"__missing__", "unknown"}:
                    missing_status = True
                row[feature] = text
                continue

            if value is None:
                if not rule.allow_missing:
                    hard_violations.append(f"{feature} cannot be missing")
                row[feature] = float("nan")
                continue
            if isinstance(value, bool) or not isinstance(value, (int, float)):
                hard_violations.append(f"{feature} must be numeric or null")
                row[feature] = float("nan")
                continue
            number = float(value)
            if not math.isfinite(number):
                hard_violations.append(f"{feature} must be finite or null")
            if rule.hard_min is not None and number < rule.hard_min - 1e-6:
                hard_violations.append(f"{feature} is below its semantic minimum")
            if rule.hard_max is not None and number > rule.hard_max + 1e-6:
                hard_violations.append(f"{feature} is above its semantic maximum")
            if rule.train_min is not None and rule.train_max is not None and (
                number < rule.train_min or number > rule.train_max
            ):
                outside_training.append(feature)
            if rule.soft_min is not None and rule.soft_max is not None and (
                number < rule.soft_min or number > rule.soft_max
            ):
                outside_soft.append(feature)
            row[feature] = number

        if hard_violations:
            raise ReliabilityInputError("; ".join(sorted(set(hard_violations))))
        policy = self.contract.ood_policy
        must_abstain = (
            missing_status
            or bool(unknown_categories)
            or len(outside_training) > policy.max_outside_training_range
            or len(outside_soft) > policy.max_outside_soft_range
        )
        messages: list[str] = []
        if missing_status:
            messages.append("latest port status is unknown; safe abstention used")
        if unknown_categories:
            messages.append(f"unknown categories: {sorted(unknown_categories)}")
        if outside_training:
            messages.append(f"{len(outside_training)} feature(s) outside training range")
        elif outside_soft:
            messages.append(f"{len(outside_soft)} feature(s) in rare training tails")
        if must_abstain and not missing_status:
            messages.append("OOD policy requires an unknown decision")
        return _PreparedReliabilityRequest(
            request=request,
            row=row,
            warnings=messages,
            outside_training_range=sorted(outside_training),
            must_abstain=must_abstain,
        )

    def _probabilities(self, prepared: Sequence[_PreparedReliabilityRequest]) -> np.ndarray:
        frame = pd.DataFrame(
            [value.row for value in prepared], columns=self.contract.feature_order
        )
        with warnings.catch_warnings():
            warnings.filterwarnings(
                "ignore",
                message="Could not find the number of physical cores.*",
                category=UserWarning,
            )
            raw = np.clip(
                np.asarray(self.base_model.predict_proba(frame)[:, 1], dtype="float64"),
                1e-6,
                1 - 1e-6,
            )
        logits = np.log(raw / (1 - raw)).reshape(-1, 1)
        calibrated = np.asarray(
            self.calibrator.predict_proba(logits)[:, 1], dtype="float64"
        )
        if len(calibrated) != len(prepared) or not bool(np.isfinite(calibrated).all()):
            raise RuntimeError("model returned invalid reliability probabilities")
        return np.clip(calibrated, 1e-6, 1 - 1e-6)

    def predict_batch(
        self, requests: Sequence[ReliabilityFeatureRequest]
    ) -> list[ReliabilityPredictionResponse]:
        if not requests:
            return []
        prepared = [self._prepare(request) for request in requests]
        model_rows = [value for value in prepared if not value.must_abstain]
        model_probabilities = iter(self._probabilities(model_rows)) if model_rows else iter(())
        low = self.contract.thresholds["reliable_max_probability_unreliable"]
        high = self.contract.thresholds["unreliable_min_probability_unreliable"]
        responses: list[ReliabilityPredictionResponse] = []
        for value in prepared:
            if value.must_abstain:
                decision: Literal["reliable", "unreliable", "unknown"] = "unknown"
                probability = None
                quality: Literal["in_domain", "warning", "abstained"] = "abstained"
            else:
                probability = float(next(model_probabilities))
                if probability <= low:
                    decision = "reliable"
                elif probability >= high:
                    decision = "unreliable"
                else:
                    decision = "unknown"
                    value.warnings.append("probability lies in calibrated abstention band")
                quality = (
                    "abstained"
                    if decision == "unknown"
                    else "warning"
                    if value.warnings
                    else "in_domain"
                )
            responses.append(
                ReliabilityPredictionResponse(
                    model_id=self.contract.model_id,
                    port_id=value.request.port_id,
                    prediction_origin=value.request.prediction_origin,
                    target_time=value.request.target_time,
                    decision=decision,
                    probability_unreliable=probability,
                    quality=quality,
                    warnings=value.warnings,
                    outside_training_range=value.outside_training_range,
                )
            )
        return responses

    def predict(self, request: ReliabilityFeatureRequest) -> ReliabilityPredictionResponse:
        return self.predict_batch([request])[0]
