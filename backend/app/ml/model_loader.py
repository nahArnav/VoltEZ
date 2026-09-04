"""
VoltEZ ML Model Loader

Loads trained models from deployment bundles with SHA-256 hash verification,
feature contract validation, and structured logging. Models are loaded once
at FastAPI startup and shared across all inference requests.

Usage:
    from app.ml.model_loader import load_model_bundle
    bundle = load_model_bundle(model_dir, manifest_path)
"""

from __future__ import annotations

import hashlib
import json
import logging
import warnings
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import joblib

logger = logging.getLogger(__name__)


@dataclass
class ModelBundle:
    """Loaded model artifact with verified metadata."""

    bundle_id: str
    model_id: str
    stage: str
    artifact_hash: str
    model: Any
    manifest: dict[str, Any]
    feature_order: list[str] = field(default_factory=list)
    feature_count: int = 0
    limitations: list[str] = field(default_factory=list)


def _compute_sha256(file_path: Path, chunk_size: int = 8192) -> str:
    """Compute SHA-256 hash of a file, reading in chunks for memory efficiency."""
    sha256 = hashlib.sha256()
    with open(file_path, "rb") as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            sha256.update(chunk)
    return sha256.hexdigest()


def load_model_bundle(
    model_dir: Path,
    strict_hash: bool = True,
) -> ModelBundle:
    """
    Load a VoltEZ model deployment bundle with full hash verification.

    Reads deployment_manifest.json for the expected SHA-256 hash, computes
    the actual hash of model.joblib, and refuses to load if they disagree.

    Args:
        model_dir: Path to the model bundle directory (e.g., models/demand/voltez-demand-60m-pune-v1/)
        strict_hash: If True, raise ValueError on hash mismatch. If False, log warning and proceed.

    Returns:
        ModelBundle with loaded model and verified metadata.

    Raises:
        FileNotFoundError: If required files are missing.
        ValueError: If hash verification fails and strict_hash=True.
    """

    # --- Locate deployment manifest ---
    deployment_manifest_path = model_dir / "deployment_manifest.json"
    manifest_path = model_dir / "manifest.json"

    if not deployment_manifest_path.exists():
        raise FileNotFoundError(f"Deployment manifest not found: {deployment_manifest_path}")

    deployment_manifest = json.loads(deployment_manifest_path.read_text("utf-8"))

    # --- Extract expected hash from deployment manifest ---
    # deployment_manifest uses either 'model_artifact_sha256' or 'artifact_sha256'
    expected_hash = deployment_manifest.get("model_artifact_sha256") or deployment_manifest.get(
        "artifact_sha256"
    )

    if not expected_hash:
        raise ValueError(
            f"No artifact hash found in deployment manifest: {deployment_manifest_path}"
        )

    bundle_id = deployment_manifest.get("bundle_id", model_dir.name)
    model_id = deployment_manifest.get("model_id", "unknown")
    stage = deployment_manifest.get("stage", deployment_manifest.get("deployment_stage", "unknown"))
    limitations = deployment_manifest.get("limitations", [])

    # --- Verify model artifact hash ---
    model_path = model_dir / "model.joblib"
    if not model_path.exists():
        raise FileNotFoundError(f"Model artifact not found: {model_path}")

    logger.info("[ML] Verifying SHA-256 hash for %s...", bundle_id)
    actual_hash = _compute_sha256(model_path)

    if actual_hash != expected_hash:
        msg = (
            f"SHA-256 hash mismatch for {bundle_id}!\n"
            f"  Expected: {expected_hash}\n"
            f"  Actual:   {actual_hash}\n"
            f"  File:     {model_path}"
        )
        if strict_hash:
            logger.error("[ML] %s", msg)
            raise ValueError(msg)
        else:
            logger.warning("[ML] %s (strict_hash=False, proceeding anyway)", msg)

    logger.info("[ML] Hash verified: %s (%s)", actual_hash[:16], bundle_id)

    # --- Load model artifact ---
    logger.info("[ML] Loading model artifact from %s...", model_path)
    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore",
            message="Setting the shape on a NumPy array has been deprecated.*",
            category=DeprecationWarning,
        )
        payload = joblib.load(model_path)

    # --- Validate payload structure ---
    if not isinstance(payload, dict):
        raise ValueError(
            f"Model payload for {bundle_id} is not a dict (got {type(payload).__name__})"
        )

    # --- Extract model and feature info based on bundle type ---
    # Demand models use 'model' key; availability models use 'base_model' + 'calibrator'
    if "model" in payload:
        model = payload["model"]
        features = payload.get("features", [])
        if isinstance(features, dict):
            feature_order = [
                str(feature)
                for group in ("numeric", "categorical")
                for feature in features.get(group, [])
            ]
        else:
            feature_order = [str(f) for f in features] if features else []
    elif "base_model" in payload:
        model = payload  # Return the full payload for availability predictor
        feature_spec = payload.get("feature_spec", {})
        numeric = feature_spec.get("numeric", [])
        categorical = feature_spec.get("categorical", [])
        feature_order = [str(f) for f in numeric] + [str(f) for f in categorical]
    else:
        # Fallback: try common keys
        model = payload.get("estimator", payload.get("predictor", payload))
        feature_order = []

    # --- Read feature contract if available ---
    feature_contract_path = model_dir / "feature_contract.json"
    if feature_contract_path.exists():
        try:
            contract = json.loads(feature_contract_path.read_text("utf-8"))
            if "feature_order" in contract:
                feature_order = contract["feature_order"]
        except (json.JSONDecodeError, KeyError):
            pass

    # --- Load secondary manifest if available ---
    manifest = {}
    if manifest_path.exists():
        try:
            manifest = json.loads(manifest_path.read_text("utf-8"))
        except json.JSONDecodeError:
            pass

    bundle = ModelBundle(
        bundle_id=bundle_id,
        model_id=model_id,
        stage=stage,
        artifact_hash=actual_hash,
        model=model,
        manifest={**deployment_manifest, **manifest},
        feature_order=feature_order,
        feature_count=len(feature_order),
        limitations=limitations,
    )

    logger.info(
        "[ML] Loaded %s: model_id=%s, stage=%s, features=%d, hash=%s",
        bundle_id,
        model_id,
        stage,
        bundle.feature_count,
        actual_hash[:16],
    )

    return bundle
