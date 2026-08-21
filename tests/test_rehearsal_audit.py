from pathlib import Path

import pytest

from voltez_ml.config import load_config
from voltez_ml.experiments.readiness import DEFAULT_EXPERIMENT_PROFILES
from voltez_ml.experiments.rehearsal import audit_rehearsal, write_rehearsal_audit
from voltez_ml.features.builder import build_feature_dataset
from voltez_ml.synthetic.generator import generate_dataset

PROJECT_ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="module")
def rehearsal_root(tmp_path_factory: pytest.TempPathFactory) -> Path:
    root = tmp_path_factory.mktemp("rehearsal-audit")
    source_dirs = []
    for experiment_profile in DEFAULT_EXPERIMENT_PROFILES:
        config = load_config(
            environment="test",
            synthetic_profile="pune_test",
            project_root=PROJECT_ROOT,
            experiment_profile=experiment_profile,
        )
        generated = generate_dataset(config, PROJECT_ROOT, root / "synthetic")
        source_dirs.append(generated.output_dir)
    feature_config = load_config(
        environment="test",
        synthetic_profile="pune_test",
        project_root=PROJECT_ROOT,
    )
    build_feature_dataset(feature_config, PROJECT_ROOT, source_dirs, root / "processed")
    return root


def test_rehearsal_audit_verifies_role_isolation_and_lineage(rehearsal_root: Path) -> None:
    report = audit_rehearsal(rehearsal_root)

    assert report["status"] == "passed_with_warnings"
    assert report["failures"] == []
    assert report["role_counts"] == {
        "stress_test": 1,
        "test": 1,
        "train": 2,
        "validation": 1,
    }
    assert set(report["demand_by_role"]) == {
        "stress_test",
        "test",
        "train",
        "validation",
    }
    assert set(report["availability_by_role"]) == {
        "stress_test",
        "test",
        "train",
        "validation",
    }


def test_rehearsal_report_is_written_once(rehearsal_root: Path) -> None:
    output = rehearsal_root / "machine_report.json"
    destination, report = write_rehearsal_audit(rehearsal_root, output)

    assert destination == output
    assert output.is_file()
    assert not output.with_name(f".{output.name}.incomplete").exists()
    assert report["trains_models"] is False
    with pytest.raises(FileExistsError, match="already exists"):
        write_rehearsal_audit(rehearsal_root, output)
