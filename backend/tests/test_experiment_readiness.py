from pathlib import Path

from voltez_ml.experiments.readiness import build_data_readiness_report

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def test_canonical_plan_has_isolated_roles_and_unique_seeds() -> None:
    report = build_data_readiness_report(
        project_root=PROJECT_ROOT,
        synthetic_profile="pune_test",
        environment="test",
    )

    assert report["status"] == "ready"
    assert report["failures"] == []
    assert report["role_counts"] == {
        "stress_test": 1,
        "test": 1,
        "train": 2,
        "validation": 1,
    }
    seeds = [run["seed"] for run in report["runs"]]
    assert len(seeds) == len(set(seeds))
    assert {run["structural_seed"] for run in report["runs"]} == {20260821}
    assert all("--environment test" in run["generation_command"] for run in report["runs"])


def test_readiness_rejects_reused_seed_and_missing_roles() -> None:
    report = build_data_readiness_report(
        project_root=PROJECT_ROOT,
        synthetic_profile="pune_test",
        experiment_profiles=("train_seed_01", "train_seed_01"),
        environment="test",
    )

    assert report["status"] == "not_ready"
    assert any("independent seed" in failure for failure in report["failures"])
    assert any("validation seed" in failure for failure in report["failures"])
    assert any("test seed" in failure for failure in report["failures"])


def test_stress_distribution_is_not_used_for_headline_evaluation() -> None:
    report = build_data_readiness_report(
        project_root=PROJECT_ROOT,
        synthetic_profile="pune_test",
        environment="test",
    )
    stress = [run for run in report["runs"] if run["evaluation_role"] == "stress_test"]
    baseline = [run for run in report["runs"] if run["evaluation_role"] == "train"]

    assert stress[0]["scenario_mix"] != baseline[0]["scenario_mix"]
    assert report["evaluation_policy"]["robustness_only_not_headline_metrics"] == ["stress_test"]


def test_structural_shift_profile_cannot_replace_canonical_scenario_stress() -> None:
    report = build_data_readiness_report(
        project_root=PROJECT_ROOT,
        synthetic_profile="pune_test",
        experiment_profiles=(
            "train_seed_01",
            "train_seed_02",
            "validation_seed_01",
            "test_seed_01",
            "structural_shift_seed_01",
        ),
        environment="test",
    )

    assert report["status"] == "not_ready"
    assert any("must share one structural seed" in item for item in report["failures"])
