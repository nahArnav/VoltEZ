"""Orchestrate reproducible VoltEZ point-in-time feature datasets."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pandas as pd

from voltez_ml.config import VoltEZConfig
from voltez_ml.features.audit import audit_feature_tables
from voltez_ml.features.availability import build_availability_features
from voltez_ml.features.demand import build_demand_features
from voltez_ml.features.splits import assign_purged_temporal_splits
from voltez_ml.synthetic.io import (
    file_sha256,
    reproducibility_fingerprint,
    write_manifest,
    write_tables,
)
from voltez_ml.synthetic.randomness import config_fingerprint

REQUIRED_TABLES = {
    "zones",
    "businesses",
    "business_hours",
    "chargers",
    "charger_ports",
    "connector_types",
    "bookings",
    "charging_sessions",
    "charger_status_events",
    "recommendation_impressions",
    "demand_buckets",
    "availability_observations",
}


class FeatureAuditError(ValueError):
    """Raised when generated features violate a leakage or consistency invariant."""


@dataclass(frozen=True)
class FeatureDataset:
    feature_snapshot_id: str
    output_dir: Path
    manifest_path: Path
    audit_path: Path
    table_paths: dict[str, Path]
    row_counts: dict[str, int]
    reproducibility_fingerprint: str


def _load_run(run_dir: Path) -> tuple[dict[str, pd.DataFrame], dict[str, Any]]:
    manifest_path = run_dir / "manifest.json"
    if not manifest_path.is_file():
        raise FileNotFoundError(f"source manifest not found: {manifest_path}")
    manifest = json.loads(manifest_path.read_text("utf-8"))
    table_metadata = manifest.get("tables", {})
    missing = REQUIRED_TABLES - set(table_metadata)
    if missing:
        raise ValueError(f"source run {run_dir} is missing tables: {sorted(missing)}")
    tables: dict[str, pd.DataFrame] = {}
    for table_name in sorted(REQUIRED_TABLES):
        metadata = table_metadata[table_name]
        table_path = run_dir / metadata["path"]
        if file_sha256(table_path) != metadata["sha256"]:
            raise ValueError(f"source table hash does not match manifest: {table_path}")
        tables[table_name] = pd.read_parquet(table_path)
    return tables, manifest


def _combine_runs(run_dirs: list[Path]) -> tuple[dict[str, pd.DataFrame], list[dict[str, Any]]]:
    loaded = [_load_run(run_dir) for run_dir in run_dirs]
    manifests = [manifest for _, manifest in loaded]
    run_ids = [str(manifest["run_id"]) for manifest in manifests]
    if len(run_ids) != len(set(run_ids)):
        raise ValueError("the same simulation run was supplied more than once")
    combined = {
        table_name: pd.concat(
            [tables[table_name] for tables, _ in loaded],
            ignore_index=True,
        )
        for table_name in sorted(REQUIRED_TABLES)
    }
    return combined, manifests


def _manifest_run_roles(manifests: list[dict[str, Any]]) -> dict[str, str]:
    """Read explicit evaluation roles while retaining legacy-manifest compatibility."""

    return {
        str(manifest["run_id"]): str(
            manifest.get("experiment", {}).get("evaluation_role", "development")
        )
        for manifest in manifests
    }


def _feature_source_hash(project_root: Path) -> str:
    digest = hashlib.sha256()
    paths = [
        *sorted((project_root / "src" / "voltez_ml" / "features").glob("*.py")),
        project_root / "src" / "voltez_ml" / "geography.py",
        project_root / "src" / "voltez_ml" / "config.py",
    ]
    for path in paths:
        digest.update(str(path.relative_to(project_root)).encode("utf-8"))
        digest.update(path.read_bytes())
    return digest.hexdigest()


def _snapshot_identity(
    config: VoltEZConfig,
    manifests: list[dict[str, Any]],
    source_hash: str,
) -> tuple[str, str]:
    identity = {
        "source_runs": [
            {
                "run_id": manifest["run_id"],
                "snapshot_id": manifest["snapshot_id"],
                "fingerprint": manifest["reproducibility_fingerprint"],
                "experiment": manifest.get("experiment", {}),
            }
            for manifest in sorted(manifests, key=lambda values: str(values["run_id"]))
        ],
        "feature_view_version": config.data.feature_view_version,
        "label_definition_version": config.data.label_definition_version,
        "time": config.time.model_dump(mode="json"),
        "features": config.features.model_dump(mode="json"),
        "feature_source_hash": source_hash,
    }
    fingerprint = config_fingerprint(identity)
    return f"features-{fingerprint[:20]}", fingerprint


def build_feature_dataset(
    config: VoltEZConfig,
    project_root: Path,
    source_run_dirs: list[Path],
    output_root: Path | None = None,
) -> FeatureDataset:
    """Load verified generator runs, build features, audit, and write atomically."""

    if not source_run_dirs:
        raise ValueError("at least one source run directory is required")
    tables, source_manifests = _combine_runs(source_run_dirs)
    run_roles = _manifest_run_roles(source_manifests)
    demand = build_demand_features(config, tables["demand_buckets"], tables["zones"])
    availability = build_availability_features(config, tables)
    demand, demand_split_report = assign_purged_temporal_splits(
        demand, config.features.split, run_roles
    )
    availability, availability_split_report = assign_purged_temporal_splits(
        availability, config.features.split, run_roles
    )
    availability_labeled = availability[availability["label"] != "unknown"].reset_index(drop=True)
    audit = audit_feature_tables(
        demand,
        availability,
        availability_labeled,
        demand_split_report,
        availability_split_report,
    )
    if audit["failures"]:
        raise FeatureAuditError("; ".join(str(value) for value in audit["failures"]))

    source_hash = _feature_source_hash(project_root)
    feature_snapshot_id, configuration_hash = _snapshot_identity(
        config, source_manifests, source_hash
    )
    destination_root = output_root or project_root / config.paths.data_root / "processed"
    destination_root.mkdir(parents=True, exist_ok=True)
    output_dir = destination_root / feature_snapshot_id
    incomplete_dir = destination_root / f".{feature_snapshot_id}.incomplete"
    previous_dir: Path | None = None
    if incomplete_dir.exists():
        raise FileExistsError(f"incomplete feature dataset requires inspection: {incomplete_dir}")
    if output_dir.exists():
        if not config.data.overwrite_existing_run:
            raise FileExistsError(f"feature dataset already exists: {output_dir}")
        previous_dir = destination_root / f"{feature_snapshot_id}.previous"
        if previous_dir.exists():
            raise FileExistsError(f"recoverable feature backup already exists: {previous_dir}")

    feature_tables = {
        "demand_features": demand,
        "availability_features_all": availability,
        "availability_features_labeled": availability_labeled,
    }
    table_metadata = write_tables(feature_tables, incomplete_dir)
    audit_path_incomplete = incomplete_dir / "audit_report.json"
    write_manifest(audit, audit_path_incomplete)
    dataset_fingerprint = reproducibility_fingerprint(table_metadata)
    manifest = {
        "feature_snapshot_id": feature_snapshot_id,
        "source_type": "synthetic",
        "source_runs": [
            {
                "run_id": manifest["run_id"],
                "snapshot_id": manifest["snapshot_id"],
                "reproducibility_fingerprint": manifest["reproducibility_fingerprint"],
                "experiment": manifest.get("experiment", {}),
            }
            for manifest in source_manifests
        ],
        "configuration_hash": configuration_hash,
        "feature_source_hash": source_hash,
        "feature_view_version": config.data.feature_view_version,
        "label_definition_version": config.data.label_definition_version,
        "materialized_at": datetime.now(UTC).isoformat(),
        "tables": table_metadata,
        "audit_report": {
            "path": audit_path_incomplete.name,
            "sha256": file_sha256(audit_path_incomplete),
            "status": audit["status"],
        },
        "row_counts": {name: len(frame) for name, frame in feature_tables.items()},
        "reproducibility_fingerprint": dataset_fingerprint,
    }
    write_manifest(manifest, incomplete_dir / "manifest.json")

    if output_dir.exists() and previous_dir is not None:
        output_dir.rename(previous_dir)
    incomplete_dir.rename(output_dir)
    return FeatureDataset(
        feature_snapshot_id=feature_snapshot_id,
        output_dir=output_dir,
        manifest_path=output_dir / "manifest.json",
        audit_path=output_dir / "audit_report.json",
        table_paths={name: output_dir / values["path"] for name, values in table_metadata.items()},
        row_counts={name: len(frame) for name, frame in feature_tables.items()},
        reproducibility_fingerprint=dataset_fingerprint,
    )
