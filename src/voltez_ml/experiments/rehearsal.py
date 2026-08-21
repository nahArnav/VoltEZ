"""Audit a completed multi-seed rehearsal without fitting either ML model."""

from __future__ import annotations

import json
from collections import Counter
from pathlib import Path
from typing import Any

import pandas as pd

from voltez_ml.synthetic.io import file_sha256, write_manifest

EXPECTED_ROLE_COUNTS = {
    "stress_test": 1,
    "test": 1,
    "train": 2,
    "validation": 1,
}
REQUIRED_FEATURE_TABLES = {
    "availability_features_all",
    "availability_features_labeled",
    "demand_features",
    "waiting_time_features_all",
    "waiting_time_features_labeled",
    "reliability_features_all",
    "reliability_features_labeled",
}


class RehearsalAuditError(ValueError):
    """Raised when rehearsal artifacts are missing, ambiguous, or corrupted."""


def _read_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise RehearsalAuditError(f"required JSON file is missing: {path}")
    values = json.loads(path.read_text("utf-8"))
    if not isinstance(values, dict):
        raise RehearsalAuditError(f"JSON root must be an object: {path}")
    return values


def _discover_artifacts(rehearsal_root: Path) -> tuple[list[Path], Path]:
    source_manifests = sorted((rehearsal_root / "synthetic").glob("sim-*/manifest.json"))
    feature_manifests = sorted((rehearsal_root / "processed").glob("features-*/manifest.json"))
    if len(source_manifests) != 5:
        raise RehearsalAuditError(
            f"expected exactly five source manifests, found {len(source_manifests)}"
        )
    if len(feature_manifests) != 1:
        raise RehearsalAuditError(
            f"expected exactly one feature manifest, found {len(feature_manifests)}"
        )
    return source_manifests, feature_manifests[0]


def _load_verified_feature_tables(
    feature_manifest_path: Path,
    feature_manifest: dict[str, Any],
) -> dict[str, pd.DataFrame]:
    metadata = feature_manifest.get("tables", {})
    missing = REQUIRED_FEATURE_TABLES - set(metadata)
    if missing:
        raise RehearsalAuditError(f"feature manifest is missing tables: {sorted(missing)}")
    tables: dict[str, pd.DataFrame] = {}
    for table_name in sorted(REQUIRED_FEATURE_TABLES):
        table_path = feature_manifest_path.parent / metadata[table_name]["path"]
        if file_sha256(table_path) != metadata[table_name]["sha256"]:
            raise RehearsalAuditError(f"feature hash mismatch: {table_path}")
        tables[table_name] = pd.read_parquet(table_path)
    return tables


def _value_counts(series: pd.Series) -> dict[str, int]:
    return {
        str(key): int(value)
        for key, value in series.astype(str).value_counts().sort_index().items()
    }


def _directory_bytes(path: Path) -> int:
    return sum(item.stat().st_size for item in path.rglob("*") if item.is_file())


def _demand_statistics(frame: pd.DataFrame) -> dict[str, Any]:
    by_role: dict[str, Any] = {}
    for role, group in frame.groupby("run_holdout_split", sort=True):
        target = pd.to_numeric(group["target_request_count"])
        by_role[str(role)] = {
            "rows": len(group),
            "target_mean": float(target.mean()),
            "target_variance": float(target.var()),
            "zero_target_rate": float((target == 0).mean()),
            "rows_by_temporal_split": _value_counts(group["split"]),
        }
    return by_role


def _availability_statistics(
    all_rows: pd.DataFrame,
    labeled_rows: pd.DataFrame,
) -> dict[str, Any]:
    by_role: dict[str, Any] = {}
    roles = sorted(all_rows["run_holdout_split"].astype(str).unique())
    for role in roles:
        role_all = all_rows[all_rows["run_holdout_split"].astype(str) == role]
        role_labeled = labeled_rows[
            labeled_rows["run_holdout_split"].astype(str) == role
        ]
        by_role[role] = {
            "all_rows": len(role_all),
            "labeled_rows": len(role_labeled),
            "unknown_rate": float((role_all["label"] == "unknown").mean()),
            "cold_start_rate": float(role_all["cold_start"].mean()),
            "label_distribution": _value_counts(role_labeled["label"]),
            "rows_by_temporal_split": _value_counts(role_labeled["split"]),
        }
    return by_role


def audit_rehearsal(rehearsal_root: Path) -> dict[str, Any]:
    """Verify lineage, role isolation, hashes, and small-sample distributions."""

    source_paths, feature_path = _discover_artifacts(rehearsal_root)
    source_manifests = [_read_json(path) for path in source_paths]
    feature_manifest = _read_json(feature_path)
    feature_audit = _read_json(feature_path.parent / "audit_report.json")
    tables = _load_verified_feature_tables(feature_path, feature_manifest)
    failures: list[str] = []
    warnings: list[str] = []

    source_by_run = {str(manifest["run_id"]): manifest for manifest in source_manifests}
    if len(source_by_run) != len(source_manifests):
        failures.append("source run IDs are not unique")
    roles_by_run = {
        run_id: str(manifest.get("experiment", {}).get("evaluation_role"))
        for run_id, manifest in source_by_run.items()
    }
    role_counts = dict(sorted(Counter(roles_by_run.values()).items()))
    if role_counts != EXPECTED_ROLE_COUNTS:
        failures.append(
            f"experiment roles do not match canonical plan: {role_counts}"
        )
    if any(bool(manifest.get("code_is_dirty")) for manifest in source_manifests):
        warnings.append("at least one source run was generated from an uncommitted worktree")

    listed_sources = {
        str(source["run_id"]): source for source in feature_manifest.get("source_runs", [])
    }
    if set(listed_sources) != set(source_by_run):
        failures.append("feature lineage does not contain exactly the five source runs")
    for run_id in set(listed_sources) & set(source_by_run):
        expected = source_by_run[run_id]["reproducibility_fingerprint"]
        if listed_sources[run_id].get("reproducibility_fingerprint") != expected:
            failures.append(f"feature lineage fingerprint mismatch for {run_id}")

    for table_name, frame in tables.items():
        if any(column.startswith(("latent_", "qa_latent_")) for column in frame.columns):
            failures.append(f"latent simulator truth leaked into {table_name}")
        if set(frame["simulation_run_id"].astype(str)) != set(source_by_run):
            failures.append(f"{table_name} does not contain exactly the expected source runs")
        expected_roles = frame["simulation_run_id"].astype(str).map(roles_by_run)
        if not bool((frame["run_holdout_split"].astype(str) == expected_roles).all()):
            failures.append(f"{table_name} contains a run-level role mismatch")

    availability_all = tables["availability_features_all"]
    availability_labeled = tables["availability_features_labeled"]
    demand = tables["demand_features"]
    if bool((availability_labeled["label"] == "unknown").any()):
        failures.append("unknown availability labels entered the supervised table")
    if set(availability_labeled["label"].astype(str)) != {"available", "unavailable"}:
        failures.append("global supervised availability data must contain both classes")
    if bool((pd.to_numeric(demand["target_request_count"]) < 0).any()):
        failures.append("demand targets contain negative values")
    if feature_audit.get("status") not in {"passed", "passed_with_warnings"}:
        failures.append(f"feature builder audit status is {feature_audit.get('status')}")

    waiting_all = tables["waiting_time_features_all"]
    waiting_labeled = tables["waiting_time_features_labeled"]
    reliability_all = tables["reliability_features_all"]
    reliability_labeled = tables["reliability_features_labeled"]
    if bool(waiting_labeled["label_wait_minutes"].isna().any()):
        failures.append("known waiting-time rows contain null targets")
    if bool((waiting_labeled["label_wait_minutes"] < 0).any()):
        failures.append("waiting-time targets contain negative values")
    if bool((reliability_labeled["label"] == "unknown").any()):
        failures.append("unknown reliability labels entered the supervised table")
    if float((waiting_labeled["label_wait_minutes"] > 0).mean()) < 0.01:
        warnings.append("waiting-time positive queue support is below 1% in the rehearsal")
    reliability_distribution = _value_counts(reliability_labeled["label"])
    if len(reliability_distribution) < 2:
        warnings.append("reliability rehearsal contains only one known class")

    unknown_rate = float((availability_all["label"] == "unknown").mean())
    cold_start_rate = float(availability_all["cold_start"].mean())
    demand_zero_rate = float((pd.to_numeric(demand["target_request_count"]) == 0).mean())
    if unknown_rate > 0.50:
        warnings.append(
            "availability unknown-label rate exceeds 50%; expected in a two-day rehearsal, "
            "but must be rechecked on the full profile"
        )
    if cold_start_rate > 0.50:
        warnings.append(
            "availability cold-start rate exceeds 50%; two days cannot establish mature port "
            "reliability history"
        )
    if demand_zero_rate > 0.95:
        warnings.append("demand targets are over 95% zero and require profile recalibration")
    for role, statistics in _availability_statistics(
        availability_all, availability_labeled
    ).items():
        label_distribution = statistics["label_distribution"]
        if len(label_distribution) < 2:
            warnings.append(
                f"availability role {role} contains only one known class in the rehearsal"
            )
            continue
        known_count = sum(label_distribution.values())
        minority_count = min(label_distribution.values())
        if minority_count < 5 or minority_count / known_count < 0.05:
            warnings.append(
                f"availability role {role} has only {minority_count} examples of its minority "
                "class; full-profile training must satisfy the class-support gate"
            )

    return {
        "status": "failed" if failures else "passed_with_warnings" if warnings else "passed",
        "trains_models": False,
        "rehearsal_root": str(rehearsal_root),
        "feature_snapshot_id": feature_manifest["feature_snapshot_id"],
        "feature_reproducibility_fingerprint": feature_manifest[
            "reproducibility_fingerprint"
        ],
        "role_counts": role_counts,
        "failures": failures,
        "warnings": warnings,
        "disk_usage_bytes": _directory_bytes(rehearsal_root),
        "source_runs": [
            {
                "run_id": manifest["run_id"],
                "experiment": manifest["experiment"],
                "seed": manifest["seed"],
                "row_counts": manifest["row_counts"],
                "reproducibility_fingerprint": manifest[
                    "reproducibility_fingerprint"
                ],
            }
            for manifest in sorted(source_manifests, key=lambda value: value["run_id"])
        ],
        "demand_by_role": _demand_statistics(demand),
        "availability_by_role": _availability_statistics(
            availability_all, availability_labeled
        ),
        "waiting_time": {
            "all_rows": len(waiting_all),
            "labeled_rows": len(waiting_labeled),
            "positive_wait_rate": float((waiting_labeled["label_wait_minutes"] > 0).mean()),
            "mean_wait_minutes": float(waiting_labeled["label_wait_minutes"].mean()),
        },
        "reliability": {
            "all_rows": len(reliability_all),
            "labeled_rows": len(reliability_labeled),
            "label_distribution": reliability_distribution,
        },
    }


def write_rehearsal_audit(
    rehearsal_root: Path,
    output_path: Path | None = None,
) -> tuple[Path, dict[str, Any]]:
    """Audit and write one immutable machine-readable report."""

    report = audit_rehearsal(rehearsal_root)
    destination = output_path or rehearsal_root / "rehearsal_audit.json"
    if destination.exists():
        raise FileExistsError(f"rehearsal audit already exists: {destination}")
    incomplete = destination.with_name(f".{destination.name}.incomplete")
    if incomplete.exists():
        raise FileExistsError(f"incomplete rehearsal audit requires inspection: {incomplete}")
    write_manifest(report, incomplete)
    incomplete.rename(destination)
    return destination, report
