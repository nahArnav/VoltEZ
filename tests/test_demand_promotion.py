import json
from pathlib import Path

import pytest

from voltez_ml.serving.promotion import promote_demand_model
from voltez_ml.synthetic.io import file_sha256, write_manifest


def _promotion_inputs(tmp_path: Path) -> dict[str, Path]:
    artifact = tmp_path / "artifact"
    artifact.mkdir()
    model = artifact / "model.joblib"
    model.write_bytes(b"model-bytes")
    training_evaluation = artifact / "evaluation_report.json"
    write_manifest({"validation": {}}, training_evaluation)
    manifest = {
        "model_id": "model-1",
        "artifact": {"path": model.name, "sha256": file_sha256(model)},
        "evaluation_report": {
            "path": training_evaluation.name,
            "sha256": file_sha256(training_evaluation),
        },
    }
    write_manifest(manifest, artifact / "manifest.json")
    contract = {
        "schema_version": "voltez-demand-serving-v1",
        "model_id": "model-1",
        "model_artifact_sha256": file_sha256(model),
        "feature_suite_manifest_sha256": "suite-hash",
        "feature_order": ["x"],
        "features": {
            "x": {
                "kind": "nonnegative",
                "train_min": 0.0,
                "train_max": 1.0,
                "soft_min": 0.0,
                "soft_max": 1.0,
                "median": 0.5,
                "missing_rate": 0.0,
                "allow_missing": False,
                "hard_min": 0.0,
                "hard_max": None,
            }
        },
        "target_spec": {
            "kind": "rolling_sum",
            "window_minutes": 60,
            "forecast_lead_minutes": 15,
            "bucket_minutes": 15,
        },
        "timezone": "Asia/Kolkata",
        "training_rows": 10,
        "target_distribution": {
            "min": 0.0,
            "max": 3.0,
            "mean": 1.0,
            "zero_rate": 0.5,
            "p99": 3.0,
        },
        "ood_policy": {
            "max_outside_training_range": 5,
            "max_outside_soft_range": 10,
            "action": "seasonal_fallback",
        },
        "fallback_feature_order": [],
    }
    contract_path = tmp_path / "contract.json"
    write_manifest(contract, contract_path)
    selection_path = tmp_path / "selection.json"
    write_manifest(
        {
            "selection_status": "frozen_before_locked_test",
            "champion": {
                "model_id": "model-1",
                "artifact_sha256": file_sha256(model),
            },
            "locked_test_touched_during_selection": False,
        },
        selection_path,
    )
    robustness_path = tmp_path / "robustness.json"
    write_manifest(
        {
            "passed": True,
            "model_artifact_sha256": file_sha256(model),
            "settings": {"locked_test_touched": False},
        },
        robustness_path,
    )
    locked_path = tmp_path / "locked.json"
    write_manifest(
        {
            "model_id": "model-1",
            "model_artifact_sha256": file_sha256(model),
            "integrity": {"locked_test_touched": True},
            "roles": {"test": {"model": {"mae": 0.7}}},
        },
        locked_path,
    )
    return {
        "artifact": artifact,
        "contract": contract_path,
        "selection": selection_path,
        "robustness": robustness_path,
        "locked": locked_path,
    }


def test_promotion_copies_only_verified_evidence(tmp_path: Path) -> None:
    inputs = _promotion_inputs(tmp_path)
    output = promote_demand_model(
        inputs["artifact"],
        inputs["contract"],
        inputs["selection"],
        inputs["robustness"],
        inputs["locked"],
        tmp_path / "bundle",
    )
    manifest = json.loads((output / "deployment_manifest.json").read_text("utf-8"))

    assert manifest["bundle_id"] == "voltez-demand-60m-pune-v1"
    assert manifest["stage"] == "synthetic_validated"
    assert manifest["locked_test_metrics"]["mae"] == 0.7
    assert manifest["serving_code"]["demand_source_sha256"]
    assert manifest["serving_code"]["promotion_source_sha256"]
    assert (output / "manifest.json").is_file()
    for name, metadata in manifest["files"].items():
        assert file_sha256(output / name) == metadata["sha256"]


def test_promotion_rejects_report_without_locked_test(tmp_path: Path) -> None:
    inputs = _promotion_inputs(tmp_path)
    locked = json.loads(inputs["locked"].read_text("utf-8"))
    locked["integrity"]["locked_test_touched"] = False
    write_manifest(locked, inputs["locked"])

    with pytest.raises(ValueError, match="one-time locked test"):
        promote_demand_model(
            inputs["artifact"],
            inputs["contract"],
            inputs["selection"],
            inputs["robustness"],
            inputs["locked"],
            tmp_path / "bundle",
        )
