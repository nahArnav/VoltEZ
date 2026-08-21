import json
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pandas as pd
import pytest

from voltez_ml.config import load_config
from voltez_ml.features import suite as suite_module
from voltez_ml.features.builder import FeatureDataset
from voltez_ml.features.suite import (
    _readiness,
    _require_matching_clean_commit,
    _source_manifests,
    build_feature_suite,
)
from voltez_ml.synthetic.io import file_sha256

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _readiness_entry(root: Path, role: str, scale: int) -> dict[str, Any]:
    role_root = root / role
    role_root.mkdir(parents=True, exist_ok=True)
    paths = {
        "demand_features": role_root / "demand.parquet",
        "availability_features_labeled": role_root / "availability.parquet",
        "waiting_time_features_labeled": role_root / "waiting.parquet",
        "reliability_features_labeled": role_root / "reliability.parquet",
    }
    pd.DataFrame({"target_request_count": [1] * scale}).to_parquet(
        paths["demand_features"], index=False
    )
    pd.DataFrame({"label": ["available"] * scale + ["unavailable"] * scale}).to_parquet(
        paths["availability_features_labeled"], index=False
    )
    pd.DataFrame({"label_wait_minutes": [5.0] * scale}).to_parquet(
        paths["waiting_time_features_labeled"], index=False
    )
    pd.DataFrame({"label": ["reliable"] * scale + ["unreliable"] * scale}).to_parquet(
        paths["reliability_features_labeled"], index=False
    )
    return {
        "evaluation_role": role,
        "tables": {name: str(path) for name, path in paths.items()},
    }


def test_readiness_is_reported_per_model_not_as_one_undifferentiated_gate(
    tmp_path: Path,
) -> None:
    entries = [
        _readiness_entry(tmp_path, "train", 1000),
        _readiness_entry(tmp_path, "validation", 300),
        _readiness_entry(tmp_path, "test", 300),
        _readiness_entry(tmp_path, "stress_test", 5),
    ]
    ready = _readiness(entries)
    assert ready["status"] == "ready"
    assert all(values["status"] == "ready" for values in ready["models"].values())

    validation_waiting = Path(
        entries[1]["tables"]["waiting_time_features_labeled"]
    )
    pd.DataFrame({"label_wait_minutes": [0.0] * 300}).to_parquet(
        validation_waiting, index=False
    )
    blocked = _readiness(entries)
    assert blocked["status"] == "not_ready"
    assert blocked["models"]["waiting_time"]["status"] == "not_ready"
    assert blocked["models"]["demand"]["status"] == "ready"


def test_source_manifest_gate_requires_canonical_clean_worlds(tmp_path: Path) -> None:
    roles = ("train", "train", "validation", "test", "stress_test")
    for index, role in enumerate(roles):
        run_root = tmp_path / f"sim-{index}"
        run_root.mkdir()
        (run_root / "manifest.json").write_text(
            json.dumps(
                {
                    "run_id": f"sim-{index}",
                    "experiment": {"evaluation_role": role},
                    "code_is_dirty": False,
                    "code_commit": "abc123",
                    "structural_namespace": "structure:pune:v1.2:20260821",
                    "dynamic_seed": index,
                }
            ),
            encoding="utf-8",
        )

    assert len(_source_manifests(tmp_path)) == 5
    dirty_path = tmp_path / "sim-0" / "manifest.json"
    dirty = json.loads(dirty_path.read_text("utf-8"))
    dirty["code_is_dirty"] = True
    dirty_path.write_text(json.dumps(dirty), encoding="utf-8")
    with pytest.raises(ValueError, match="dirty-worktree"):
        _source_manifests(tmp_path)


def test_feature_commit_gate_rejects_dirty_or_mismatched_code(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    outputs = iter(("abc123\n", ""))
    monkeypatch.setattr(
        suite_module.subprocess,
        "run",
        lambda *args, **kwargs: SimpleNamespace(stdout=next(outputs)),
    )
    _require_matching_clean_commit(PROJECT_ROOT, "abc123")

    outputs = iter(("abc123\n", "M file.py\n"))
    monkeypatch.setattr(
        suite_module.subprocess,
        "run",
        lambda *args, **kwargs: SimpleNamespace(stdout=next(outputs)),
    )
    with pytest.raises(ValueError, match="clean worktree"):
        _require_matching_clean_commit(PROJECT_ROOT, "abc123")

    outputs = iter(("different\n", ""))
    monkeypatch.setattr(
        suite_module.subprocess,
        "run",
        lambda *args, **kwargs: SimpleNamespace(stdout=next(outputs)),
    )
    with pytest.raises(ValueError, match="does not match"):
        _require_matching_clean_commit(PROJECT_ROOT, "abc123")


def test_suite_manifest_uses_portable_relative_paths(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    roles = ("train", "train", "validation", "test", "stress_test")
    sources = [
        (
            tmp_path / "raw" / f"sim-{index}",
            {
                "run_id": f"sim-{index}",
                "code_commit": "abc123",
                "experiment": {"evaluation_role": role, "name": f"seed-{index}"},
                "structural_namespace": "structure:pune:v1.2:20260821",
                "dynamic_seed": index,
            },
        )
        for index, role in enumerate(roles)
    ]
    for source, manifest in sources:
        source.mkdir(parents=True)
        (source / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

    def fake_build(
        config: Any,
        project_root: Path,
        source_dirs: list[Path],
        output_root: Path,
    ) -> FeatureDataset:
        del config, project_root
        run_id = source_dirs[0].name
        destination = output_root / f"features-{run_id}"
        destination.mkdir(parents=True)
        table = destination / "demand_features.parquet"
        pd.DataFrame({"target_request_count": [1]}).to_parquet(table, index=False)
        manifest = destination / "manifest.json"
        manifest.write_text("{}", encoding="utf-8")
        audit = destination / "audit_report.json"
        audit.write_text("{}", encoding="utf-8")
        return FeatureDataset(
            feature_snapshot_id=destination.name,
            output_dir=destination,
            manifest_path=manifest,
            audit_path=audit,
            table_paths={"demand_features": table},
            row_counts={"demand_features": 1},
            reproducibility_fingerprint=run_id,
        )

    monkeypatch.setattr(suite_module, "_source_manifests", lambda root: sources)
    monkeypatch.setattr(
        suite_module, "_require_matching_clean_commit", lambda root, commit: None
    )
    monkeypatch.setattr(suite_module, "build_feature_dataset", fake_build)
    monkeypatch.setattr(
        suite_module,
        "_readiness",
        lambda entries: {"status": "ready", "failures": [], "models": {}},
    )
    output_root = tmp_path / "features"
    result = build_feature_suite(
        load_config(project_root=PROJECT_ROOT),
        PROJECT_ROOT,
        tmp_path / "raw",
        output_root,
    )
    manifest = json.loads(result.manifest_path.read_text("utf-8"))

    assert manifest["source_root"] == "../raw"
    assert manifest["training_readiness"]["path"] == "training_readiness.json"
    assert all(
        not Path(entry["feature_manifest"]).is_absolute()
        for entry in manifest["datasets"]
    )
    assert file_sha256(result.readiness_path) == manifest["training_readiness"]["sha256"]
