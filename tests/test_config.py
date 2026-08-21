from pathlib import Path

import pytest
from pydantic import ValidationError

from voltez_ml.config import VoltEZConfig, _deep_merge, load_config

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def test_development_config_loads_expected_project_defaults() -> None:
    config = load_config(project_root=PROJECT_ROOT)

    assert config.project.city == "Pune"
    assert config.project.structural_seed == 20260821
    assert config.project.timezone == "Asia/Kolkata"
    assert config.time.bucket_minutes == 15
    assert config.time.demand_horizons_minutes == [15, 30, 60, 120, 360]
    assert config.execution.device == "cpu"


def test_test_environment_overrides_only_targeted_values() -> None:
    config = load_config(environment="test", project_root=PROJECT_ROOT)

    assert config.environment.name == "test"
    assert config.execution.thread_count == 1
    assert config.execution.memory_budget_gb == 1.0
    assert config.project.city == "Pune"


def test_deep_merge_does_not_mutate_inputs() -> None:
    base = {"execution": {"device": "cpu", "thread_count": -1}}
    override = {"execution": {"thread_count": 1}}

    merged = _deep_merge(base, override)

    assert merged == {"execution": {"device": "cpu", "thread_count": 1}}
    assert base == {"execution": {"device": "cpu", "thread_count": -1}}
    assert override == {"execution": {"thread_count": 1}}


def test_scenario_probabilities_must_sum_to_one() -> None:
    config = load_config(project_root=PROJECT_ROOT)
    values = config.model_dump()
    values["synthetic"]["scenario_mix"]["normal_weekday"] = 0.20

    with pytest.raises(ValidationError, match="scenario probabilities must sum to 1.0"):
        VoltEZConfig.model_validate(values)


def test_demand_horizons_must_align_with_bucket_size() -> None:
    config = load_config(project_root=PROJECT_ROOT)
    values = config.model_dump()
    values["time"]["demand_horizons_minutes"] = [15, 20]

    with pytest.raises(ValidationError, match="positive multiples of bucket_minutes"):
        VoltEZConfig.model_validate(values)


def test_memory_budget_protects_sixteen_gigabyte_machine() -> None:
    config = load_config(project_root=PROJECT_ROOT)
    values = config.model_dump()
    values["execution"]["memory_budget_gb"] = 14

    with pytest.raises(ValidationError):
        VoltEZConfig.model_validate(values)


def test_zero_threads_is_rejected() -> None:
    config = load_config(project_root=PROJECT_ROOT)
    values = config.model_dump()
    values["execution"]["thread_count"] = 0

    with pytest.raises(ValidationError, match="thread_count must be -1"):
        VoltEZConfig.model_validate(values)


def test_availability_eta_buckets_must_be_sorted_and_unique() -> None:
    config = load_config(project_root=PROJECT_ROOT)
    values = config.model_dump()
    values["time"]["availability_eta_buckets_minutes"] = [30, 15, 30]

    with pytest.raises(ValidationError, match="unique and sorted"):
        VoltEZConfig.model_validate(values)


def test_supply_port_range_must_be_ordered() -> None:
    config = load_config(project_root=PROJECT_ROOT)
    values = config.model_dump()
    values["synthetic"]["supply"]["minimum_ports_per_charger"] = 4
    values["synthetic"]["supply"]["maximum_ports_per_charger"] = 2

    with pytest.raises(ValidationError, match="cannot be smaller"):
        VoltEZConfig.model_validate(values)


def test_cancellation_and_no_show_probabilities_leave_room_for_attendance() -> None:
    config = load_config(project_root=PROJECT_ROOT)
    values = config.model_dump()
    values["synthetic"]["behaviour"]["cancellation_probability"] = 0.60
    values["synthetic"]["behaviour"]["no_show_probability"] = 0.40

    with pytest.raises(ValidationError, match="must sum to less than 1"):
        VoltEZConfig.model_validate(values)


def test_feature_split_fractions_must_sum_to_one() -> None:
    config = load_config(project_root=PROJECT_ROOT)
    values = config.model_dump()
    values["features"]["split"]["test_fraction"] = 0.20

    with pytest.raises(ValidationError, match="split fractions must sum to 1.0"):
        VoltEZConfig.model_validate(values)


def test_demand_feature_windows_must_be_positive_sorted_and_unique() -> None:
    config = load_config(project_root=PROJECT_ROOT)
    values = config.model_dump()
    values["features"]["demand_recent_windows_buckets"] = [1, 4, 2, 4]

    with pytest.raises(ValidationError, match="positive, unique, and sorted"):
        VoltEZConfig.model_validate(values)


def test_minimum_history_cannot_be_shorter_than_smallest_window() -> None:
    config = load_config(project_root=PROJECT_ROOT)
    values = config.model_dump()
    values["features"]["demand_recent_windows_buckets"] = [4, 8]
    values["features"]["demand_minimum_history_buckets"] = 2

    with pytest.raises(ValidationError, match="cannot be shorter"):
        VoltEZConfig.model_validate(values)


def test_experiment_overlay_changes_seed_and_declares_role() -> None:
    config = load_config(
        project_root=PROJECT_ROOT,
        experiment_profile="validation_seed_01",
    )

    assert config.project.seed == 20261013
    assert config.project.structural_seed == 20260821
    assert config.experiment.name == "validation_seed_01"
    assert config.experiment.evaluation_role == "validation"
