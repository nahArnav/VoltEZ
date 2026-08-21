"""Sequential, memory-safe assembly of the canonical five-world feature suite."""

from __future__ import annotations

import json
import os
import subprocess
from collections import Counter
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pandas as pd

from voltez_ml.config import VoltEZConfig
from voltez_ml.features.builder import FeatureDataset, build_feature_dataset
from voltez_ml.synthetic.io import file_sha256, write_manifest

EXPECTED_ROLE_COUNTS = {"train": 2, "validation": 1, "test": 1, "stress_test": 1}


@dataclass(frozen=True)
class FeatureSuite:
    output_root: Path
    manifest_path: Path
    readiness_path: Path
    feature_datasets: tuple[FeatureDataset, ...]


def _source_manifests(source_root: Path) -> list[tuple[Path, dict[str, Any]]]:
    paths = sorted(source_root.glob("sim-*/manifest.json"))
    loaded = [(path.parent, json.loads(path.read_text("utf-8"))) for path in paths]
    roles = Counter(
        str(manifest.get("experiment", {}).get("evaluation_role"))
        for _, manifest in loaded
    )
    if dict(sorted(roles.items())) != EXPECTED_ROLE_COUNTS:
        raise ValueError(
            "source root must contain the canonical two-train/validation/test/stress worlds; "
            f"received {dict(sorted(roles.items()))}"
        )
    if any(bool(manifest.get("code_is_dirty")) for _, manifest in loaded):
        raise ValueError("final feature suites cannot be built from dirty-worktree source runs")
    commits = {manifest.get("code_commit") for _, manifest in loaded}
    if len(commits) != 1 or None in commits:
        raise ValueError("all final source worlds must come from one clean code commit")
    return loaded


def _require_matching_clean_commit(project_root: Path, expected_commit: str) -> None:
    commit = subprocess.run(
        ["/usr/bin/git", "rev-parse", "HEAD"],
        cwd=project_root,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    dirty = subprocess.run(
        ["/usr/bin/git", "status", "--porcelain"],
        cwd=project_root,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    if dirty:
        raise ValueError("final feature suites must be built from a clean worktree")
    if commit != expected_commit:
        raise ValueError(
            "feature code commit does not match the source-world commit; regenerate or check out "
            "the recorded source commit"
        )


def _label_counts(path: Path, column: str) -> dict[str, int]:
    values = pd.read_parquet(path, columns=[column])[column]
    return {str(key): int(value) for key, value in values.value_counts().sort_index().items()}


def _readiness(entries: list[dict[str, Any]]) -> dict[str, Any]:
    by_role: dict[str, dict[str, Any]] = {}
    for entry in entries:
        role = str(entry["evaluation_role"])
        role_values = by_role.setdefault(
            role,
            {
                "demand_rows": 0,
                "demand_nonzero_targets": 0,
                "availability_labels": Counter(),
                "waiting_rows": 0,
                "waiting_positive_targets": 0,
                "reliability_labels": Counter(),
            },
        )
        tables = entry["tables"]
        demand_path = Path(tables["demand_features"])
        demand_target = pd.read_parquet(
            demand_path, columns=["target_request_count"]
        )["target_request_count"]
        role_values["demand_rows"] += len(demand_target)
        role_values["demand_nonzero_targets"] += int((demand_target > 0).sum())
        role_values["availability_labels"].update(
            _label_counts(Path(tables["availability_features_labeled"]), "label")
        )
        waiting_target = pd.read_parquet(
            Path(tables["waiting_time_features_labeled"]),
            columns=["label_wait_minutes"],
        )["label_wait_minutes"]
        role_values["waiting_rows"] += len(waiting_target)
        role_values["waiting_positive_targets"] += int((waiting_target > 0).sum())
        role_values["reliability_labels"].update(
            _label_counts(Path(tables["reliability_features_labeled"]), "label")
        )

    failures_by_model: dict[str, list[str]] = {
        "demand": [],
        "availability": [],
        "waiting_time": [],
        "reliability": [],
    }
    thresholds = {
        "train": {"demand": 1000, "availability": 50, "waiting": 100, "reliability": 100},
        "validation": {"demand": 300, "availability": 20, "waiting": 25, "reliability": 25},
        "test": {"demand": 300, "availability": 20, "waiting": 25, "reliability": 25},
    }
    for role, gates in thresholds.items():
        values = by_role[role]
        if values["demand_nonzero_targets"] < gates["demand"]:
            failures_by_model["demand"].append(
                f"{role}: insufficient nonzero demand targets"
            )
        availability = values["availability_labels"]
        if min(availability.get("available", 0), availability.get("unavailable", 0)) < gates[
            "availability"
        ]:
            failures_by_model["availability"].append(
                f"{role}: insufficient availability minority support"
            )
        if values["waiting_positive_targets"] < gates["waiting"]:
            failures_by_model["waiting_time"].append(
                f"{role}: insufficient positive waiting-time support"
            )
        reliability = values["reliability_labels"]
        if min(reliability.get("reliable", 0), reliability.get("unreliable", 0)) < gates[
            "reliability"
        ]:
            failures_by_model["reliability"].append(
                f"{role}: insufficient reliability minority support"
            )

    serializable: dict[str, Any] = {}
    for role, values in sorted(by_role.items()):
        serializable[role] = {
            **values,
            "availability_labels": dict(sorted(values["availability_labels"].items())),
            "reliability_labels": dict(sorted(values["reliability_labels"].items())),
        }
    model_readiness = {
        model: {
            "status": "ready" if not failures else "not_ready",
            "failures": failures,
        }
        for model, failures in failures_by_model.items()
    }
    all_failures = [
        f"{model}: {failure}"
        for model, failures in failures_by_model.items()
        for failure in failures
    ]
    return {
        "status": "ready" if not all_failures else "not_ready",
        "failures": all_failures,
        "models": model_readiness,
        "gates_apply_to": ["train", "validation", "test"],
        "stress_test_is_robustness_only": True,
        "by_role": serializable,
    }


def build_feature_suite(
    config: VoltEZConfig,
    project_root: Path,
    source_root: Path,
    output_root: Path,
) -> FeatureSuite:
    """Build one run at a time, then index and audit the complete training handoff."""

    sources = _source_manifests(source_root)
    expected_commit = str(sources[0][1]["code_commit"])
    _require_matching_clean_commit(project_root, expected_commit)
    output_root.mkdir(parents=True, exist_ok=True)
    manifest_path = output_root / "feature_suite_manifest.json"
    readiness_path = output_root / "training_readiness.json"
    if manifest_path.exists() or readiness_path.exists():
        raise FileExistsError("feature suite outputs already exist; preserve them as immutable")

    datasets: list[FeatureDataset] = []
    entries: list[dict[str, Any]] = []
    for source_dir, source_manifest in sources:
        result = build_feature_dataset(config, project_root, [source_dir], output_root)
        datasets.append(result)
        entries.append(
            {
                "run_id": source_manifest["run_id"],
                "evaluation_role": source_manifest["experiment"]["evaluation_role"],
                "experiment_name": source_manifest["experiment"]["name"],
                "source_manifest": str(source_dir / "manifest.json"),
                "feature_snapshot_id": result.feature_snapshot_id,
                "feature_manifest": str(result.manifest_path),
                "tables": {
                    name: str(path) for name, path in sorted(result.table_paths.items())
                },
                "row_counts": result.row_counts,
            }
        )

    readiness = _readiness(entries)
    write_manifest(readiness, readiness_path.with_name(f".{readiness_path.name}.incomplete"))
    readiness_path.with_name(f".{readiness_path.name}.incomplete").rename(readiness_path)
    portable_entries = [
        {
            **entry,
            "source_manifest": os.path.relpath(entry["source_manifest"], output_root),
            "feature_manifest": os.path.relpath(entry["feature_manifest"], output_root),
            "tables": {
                name: os.path.relpath(path, output_root)
                for name, path in entry["tables"].items()
            },
        }
        for entry in entries
    ]
    suite_manifest = {
        "created_at": datetime.now(UTC).isoformat(),
        "source_root": os.path.relpath(source_root, output_root),
        "code_commit": expected_commit,
        "feature_view_version": config.data.feature_view_version,
        "label_definition_version": config.data.label_definition_version,
        "memory_policy": "one source world is loaded and materialized at a time",
        "training_readiness": {
            "path": readiness_path.name,
            "sha256": file_sha256(readiness_path),
            "status": readiness["status"],
        },
        "datasets": portable_entries,
    }
    incomplete_manifest = manifest_path.with_name(f".{manifest_path.name}.incomplete")
    write_manifest(suite_manifest, incomplete_manifest)
    incomplete_manifest.rename(manifest_path)
    return FeatureSuite(
        output_root=output_root,
        manifest_path=manifest_path,
        readiness_path=readiness_path,
        feature_datasets=tuple(datasets),
    )
