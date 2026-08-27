"""Immutable deployment-bundle promotion for the frozen Model 1 champion."""

from __future__ import annotations

import json
import shutil
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from voltez_ml.serving import demand as demand_serving
from voltez_ml.serving.demand import DemandFeatureContract
from voltez_ml.synthetic.io import file_sha256, write_manifest
from voltez_ml.training.demand_window import _git_state


def _read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text("utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected a JSON object: {path}")
    return value


def promote_demand_model(
    artifact_dir: Path,
    feature_contract_path: Path,
    selection_manifest_path: Path,
    robustness_audit_path: Path,
    locked_test_report_path: Path,
    output_dir: Path,
) -> Path:
    """Copy verified evidence into a self-contained, immutable serving bundle."""

    if output_dir.exists():
        raise FileExistsError(f"deployment bundle already exists: {output_dir}")
    artifact_manifest_path = artifact_dir / "manifest.json"
    artifact_manifest = _read_json(artifact_manifest_path)
    model_path = artifact_dir / str(artifact_manifest["artifact"]["path"])
    model_hash = file_sha256(model_path)
    if model_hash != artifact_manifest["artifact"]["sha256"]:
        raise ValueError("selected model artifact hash is invalid")

    contract = DemandFeatureContract.model_validate_json(feature_contract_path.read_text("utf-8"))
    if contract.model_id != artifact_manifest["model_id"]:
        raise ValueError("serving contract model id does not match the selected artifact")
    if contract.model_artifact_sha256 != model_hash:
        raise ValueError("serving contract model hash does not match the selected artifact")

    selection = _read_json(selection_manifest_path)
    champion = selection.get("champion", {})
    if selection.get("selection_status") != "frozen_before_locked_test":
        raise ValueError("champion was not frozen before locked-test access")
    if champion.get("model_id") != contract.model_id:
        raise ValueError("selection manifest names a different champion")
    if champion.get("artifact_sha256") != model_hash:
        raise ValueError("selection manifest champion hash is invalid")
    if selection.get("locked_test_touched_during_selection") is not False:
        raise ValueError("selection manifest does not prove test isolation")

    robustness = _read_json(robustness_audit_path)
    if robustness.get("passed") is not True:
        raise ValueError("serving robustness audit did not pass")
    if robustness.get("model_artifact_sha256") != model_hash:
        raise ValueError("robustness audit belongs to a different artifact")
    if robustness.get("settings", {}).get("locked_test_touched") is not False:
        raise ValueError("robustness audit unexpectedly touched the locked test")

    locked_test = _read_json(locked_test_report_path)
    integrity = locked_test.get("integrity", {})
    if integrity.get("locked_test_touched") is not True:
        raise ValueError("final evaluation does not contain the one-time locked test")
    if locked_test.get("model_id") != contract.model_id:
        raise ValueError("locked-test report belongs to a different model")
    if locked_test.get("model_artifact_sha256") != model_hash:
        raise ValueError("locked-test report artifact hash is invalid")
    if "test" not in locked_test.get("roles", {}):
        raise ValueError("locked-test report has no test role")

    training_report_path = artifact_dir / str(artifact_manifest["evaluation_report"]["path"])
    if file_sha256(training_report_path) != artifact_manifest["evaluation_report"]["sha256"]:
        raise ValueError("training evaluation report hash is invalid")

    output_dir.mkdir(parents=True)
    inputs = {
        "model.joblib": model_path,
        "manifest.json": artifact_manifest_path,
        "training_evaluation.json": training_report_path,
        "feature_contract.json": feature_contract_path,
        "selection_manifest.json": selection_manifest_path,
        "robustness_audit.json": robustness_audit_path,
        "locked_test_evaluation.json": locked_test_report_path,
    }
    files: dict[str, dict[str, str | int]] = {}
    for destination_name, source in inputs.items():
        destination = output_dir / destination_name
        shutil.copy2(source, destination)
        files[destination_name] = {
            "sha256": file_sha256(destination),
            "bytes": destination.stat().st_size,
        }

    test_metrics = locked_test["roles"]["test"]["model"]
    code_state = _git_state(Path.cwd().resolve())
    manifest = {
        "bundle_schema": "voltez-model-bundle-v1",
        "bundle_id": "voltez-demand-60m-pune-v1",
        "model_id": contract.model_id,
        "model_artifact_sha256": model_hash,
        "stage": "synthetic_validated",
        "created_at": datetime.now(UTC).isoformat(),
        "serving_class": "voltez_ml.serving.demand.DemandPredictor",
        "serving_code": {
            **code_state,
            "demand_source_sha256": file_sha256(Path(demand_serving.__file__).resolve()),
            "promotion_source_sha256": file_sha256(Path(__file__).resolve()),
        },
        "target_spec": contract.target_spec,
        "timezone": contract.timezone,
        "locked_test_metrics": test_metrics,
        "limitations": [
            "trained and evaluated on synthetic Pune worlds, not production VoltEZ traffic",
            "returns conditional expected demand and smooths rare demand spikes",
            "requires shadow monitoring and real-label collection before production promotion",
        ],
        "files": files,
    }
    write_manifest(manifest, output_dir / "deployment_manifest.json")
    return output_dir
