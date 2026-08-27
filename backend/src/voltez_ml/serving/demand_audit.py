"""Robustness audit for the frozen Model 1 application contract."""

from __future__ import annotations

from copy import deepcopy
from pathlib import Path
from typing import Any

import numpy as np

from voltez_ml.serving.demand import (
    DemandFeatureRequest,
    DemandInputError,
    DemandPredictor,
    quality_counts,
    requests_from_frame,
)
from voltez_ml.synthetic.io import file_sha256, write_manifest
from voltez_ml.training.demand import _load_suite
from voltez_ml.training.demand_window import DemandWindowSettings, _window_role


def _is_rejected(predictor: DemandPredictor, request: DemandFeatureRequest) -> bool:
    try:
        predictor.predict(request)
    except DemandInputError:
        return True
    return False


def _extreme_request(
    predictor: DemandPredictor, request: DemandFeatureRequest
) -> DemandFeatureRequest:
    changed = request.model_copy(deep=True)
    candidates = [
        name
        for name in predictor.contract.feature_order
        if predictor.contract.features[name].kind == "nonnegative"
        and name
        not in {
            "request_sum_same_window_last_week",
            "request_sum_same_window_yesterday",
            "request_ewm_prior",
        }
    ]
    required = predictor.contract.ood_policy.max_outside_training_range + 1
    if len(candidates) < required:
        raise ValueError("contract has too few nonnegative features for its OOD audit")
    for name in candidates[:required]:
        rule = predictor.contract.features[name]
        changed.features[name] = rule.train_max + max(10.0, rule.train_max)
    return changed


def audit_demand_serving(
    artifact_dir: Path,
    contract_path: Path,
    suite_manifest_path: Path,
    output_path: Path,
    sample_rows_per_role: int = 5_000,
    random_seed: int = 20260821,
) -> Path:
    """Exercise unseen roles and malformed/OOD cases without loading the locked test."""

    if sample_rows_per_role <= 0:
        raise ValueError("sample rows per role must be positive")
    predictor = DemandPredictor.from_artifact(artifact_dir, contract_path)
    if file_sha256(suite_manifest_path) != predictor.contract.feature_suite_manifest_sha256:
        raise ValueError("serving contract and audit feature suite do not match")
    suite, _ = _load_suite(suite_manifest_path)
    target_spec = predictor.contract.target_spec
    settings = DemandWindowSettings(
        window_minutes=int(target_spec["window_minutes"]),
        forecast_lead_minutes=int(target_spec["forecast_lead_minutes"]),
        bucket_minutes=int(target_spec["bucket_minutes"]),
    )

    roles: dict[str, Any] = {}
    for role_index, role in enumerate(("validation", "stress_test")):
        frame = _window_role(suite, role, settings)
        sample = frame.sample(
            n=min(sample_rows_per_role, len(frame)),
            random_state=random_seed + role_index,
        )
        requests = requests_from_frame(sample, predictor.contract.feature_order)
        responses = predictor.predict_batch(requests)
        model_indices = [
            index for index, response in enumerate(responses) if not response.used_fallback
        ]
        raw_difference = 0.0
        if model_indices:
            matrix = sample.iloc[model_indices][predictor.contract.feature_order].astype("float32")
            raw_prediction = np.clip(
                np.asarray(predictor.model.predict(matrix), dtype="float64"),
                0.0,
                None,
            )
            served_prediction = np.array(
                [responses[index].expected_requests for index in model_indices],
                dtype="float64",
            )
            raw_difference = float(np.max(np.abs(raw_prediction - served_prediction)))
        roles[role] = {
            "rows": len(sample),
            "quality_counts": quality_counts(responses),
            "fallback_rate": float(np.mean([response.used_fallback for response in responses])),
            "finite_nonnegative_predictions": bool(
                all(
                    math_value >= 0 and np.isfinite(math_value)
                    for math_value in (response.expected_requests for response in responses)
                )
            ),
            "max_model_vs_serving_difference": raw_difference,
        }

    validation_frame = _window_role(suite, "validation", settings)
    base_request = requests_from_frame(validation_frame.iloc[:1], predictor.contract.feature_order)[
        0
    ]
    negative = base_request.model_copy(deep=True)
    negative.features["request_lag_1"] = -1.0
    calendar = base_request.model_copy(deep=True)
    calendar.features["target_hour_sin"] = float(calendar.features["target_hour_sin"] or 0) + 0.2
    missing = base_request.model_copy(deep=True)
    missing.features.pop(predictor.contract.feature_order[0])
    extreme = _extreme_request(predictor, base_request)
    extreme_response = predictor.predict(extreme)
    repeated_a = predictor.predict_batch([deepcopy(base_request) for _ in range(10)])
    repeated_b = predictor.predict_batch([deepcopy(base_request) for _ in range(10)])
    deterministic = [value.expected_requests for value in repeated_a] == [
        value.expected_requests for value in repeated_b
    ]
    adversarial = {
        "negative_count_rejected": _is_rejected(predictor, negative),
        "calendar_mismatch_rejected": _is_rejected(predictor, calendar),
        "missing_feature_rejected": _is_rejected(predictor, missing),
        "multi_feature_shift_uses_fallback": extreme_response.used_fallback,
        "repeated_batch_is_deterministic": deterministic,
    }
    checks = {
        "validation_fallback_below_1_percent": roles["validation"]["fallback_rate"] <= 0.01,
        "stress_fallback_below_5_percent": roles["stress_test"]["fallback_rate"] <= 0.05,
        "serving_matches_estimator": all(
            values["max_model_vs_serving_difference"] <= 1e-12 for values in roles.values()
        ),
        "all_predictions_finite_nonnegative": all(
            values["finite_nonnegative_predictions"] for values in roles.values()
        ),
        "all_adversarial_checks_pass": all(adversarial.values()),
    }
    report = {
        "audit_type": "voltez-demand-serving-robustness-v1",
        "model_id": predictor.contract.model_id,
        "model_artifact_sha256": predictor.contract.model_artifact_sha256,
        "feature_contract_sha256": file_sha256(contract_path),
        "feature_suite_manifest_sha256": file_sha256(suite_manifest_path),
        "settings": {
            "roles": ["validation", "stress_test"],
            "locked_test_touched": False,
            "sample_rows_per_role": sample_rows_per_role,
            "random_seed": random_seed,
        },
        "roles": roles,
        "adversarial": adversarial,
        "checks": checks,
        "passed": all(checks.values()),
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    write_manifest(report, output_path)
    return output_path
