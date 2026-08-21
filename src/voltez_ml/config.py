"""Typed configuration loading for the VoltEZ ML project.

This module deliberately contains no data-generation or model-training logic. Its only job is
to combine versioned YAML settings and reject invalid configurations before expensive work starts.
"""

from __future__ import annotations

from copy import deepcopy
from datetime import date
from pathlib import Path
from typing import Any, Literal

import yaml
from pydantic import BaseModel, ConfigDict, Field, model_validator


class StrictConfigModel(BaseModel):
    """Reject misspelled or unexpected configuration fields."""

    model_config = ConfigDict(extra="forbid")


class ProjectSettings(StrictConfigModel):
    name: str = "voltez-ml"
    seed: int = Field(ge=0)
    timezone: str
    city: str


class ExperimentSettings(StrictConfigModel):
    """Describe how one independently seeded run may be used during evaluation."""

    name: str = Field(min_length=1, pattern=r"^[a-z0-9][a-z0-9_-]*$")
    evaluation_role: Literal[
        "development",
        "train",
        "validation",
        "test",
        "stress_test",
    ] = "development"


class PathSettings(StrictConfigModel):
    data_root: Path
    artifact_root: Path
    report_root: Path


class ExecutionSettings(StrictConfigModel):
    device: Literal["cpu", "mps", "cuda"] = "cpu"
    thread_count: int = Field(default=-1, ge=-1)
    memory_budget_gb: float = Field(gt=0, le=12)
    deterministic: bool = True

    @model_validator(mode="after")
    def reject_zero_threads(self) -> ExecutionSettings:
        if self.thread_count == 0:
            raise ValueError("thread_count must be -1 for automatic selection or at least 1")
        return self


class TimeSettings(StrictConfigModel):
    bucket_minutes: int = Field(gt=0)
    demand_horizons_minutes: list[int]
    availability_eta_buckets_minutes: list[int]

    @model_validator(mode="after")
    def validate_time_grid(self) -> TimeSettings:
        if 60 % self.bucket_minutes != 0:
            raise ValueError("bucket_minutes must divide evenly into one hour")

        if not self.demand_horizons_minutes:
            raise ValueError("at least one demand horizon is required")

        invalid_horizons = [
            horizon
            for horizon in self.demand_horizons_minutes
            if horizon <= 0 or horizon % self.bucket_minutes != 0
        ]
        if invalid_horizons:
            raise ValueError(
                f"demand horizons must be positive multiples of bucket_minutes: {invalid_horizons}"
            )

        if sorted(set(self.demand_horizons_minutes)) != self.demand_horizons_minutes:
            raise ValueError("demand horizons must be unique and sorted")

        if any(bucket <= 0 for bucket in self.availability_eta_buckets_minutes):
            raise ValueError("availability ETA buckets must be positive")

        if (
            sorted(set(self.availability_eta_buckets_minutes))
            != self.availability_eta_buckets_minutes
        ):
            raise ValueError("availability ETA buckets must be unique and sorted")

        return self


class DataSettings(StrictConfigModel):
    source: Literal["synthetic", "real", "mixed"]
    output_format: Literal["parquet"] = "parquet"
    include_personal_data: bool = False
    feature_view_version: str
    label_definition_version: str
    overwrite_existing_run: bool = False


class SplitSettings(StrictConfigModel):
    train_fraction: float = Field(default=0.70, gt=0, lt=1)
    validation_fraction: float = Field(default=0.15, gt=0, lt=1)
    test_fraction: float = Field(default=0.15, gt=0, lt=1)

    @model_validator(mode="after")
    def validate_fractions(self) -> SplitSettings:
        total = self.train_fraction + self.validation_fraction + self.test_fraction
        if abs(total - 1.0) > 1e-9:
            raise ValueError(f"split fractions must sum to 1.0, received {total}")
        return self


class FeatureSettings(StrictConfigModel):
    demand_recent_windows_buckets: list[int]
    demand_ewm_span_buckets: int = Field(gt=1)
    demand_minimum_history_buckets: int = Field(gt=0)
    availability_history_hours: int = Field(gt=0)
    waiting_history_hours: int = Field(gt=0)
    reliability_history_days: int = Field(gt=0)
    reliability_prior_successes: float = Field(gt=0)
    reliability_prior_failures: float = Field(gt=0)
    cold_start_evidence_threshold: int = Field(gt=0)
    split: SplitSettings

    @model_validator(mode="after")
    def validate_feature_windows(self) -> FeatureSettings:
        windows = self.demand_recent_windows_buckets
        if not windows or sorted(set(windows)) != windows or any(window <= 0 for window in windows):
            raise ValueError("demand recent windows must be positive, unique, and sorted")
        if self.demand_minimum_history_buckets < min(windows):
            raise ValueError("minimum demand history cannot be shorter than the smallest window")
        return self


class EnvironmentSettings(StrictConfigModel):
    name: Literal["development", "test"]
    fail_on_validation_error: bool = True


class DemandSyntheticSettings(StrictConfigModel):
    average_requests_per_zone_per_day: float = Field(gt=0)
    negative_binomial_dispersion: float = Field(gt=0)
    spatial_spillover_weight: float = Field(ge=0, le=1)


class AvailabilitySyntheticSettings(StrictConfigModel):
    base_operational_probability: float = Field(ge=0, le=1)
    owner_report_error_probability: float = Field(ge=0, le=1)
    user_report_error_probability: float = Field(ge=0, le=1)
    median_status_ttl_minutes: int = Field(gt=0)


class SupplySyntheticSettings(StrictConfigModel):
    minimum_ports_per_charger: int = Field(default=1, gt=0, le=8)
    maximum_ports_per_charger: int = Field(default=3, gt=0, le=8)

    @model_validator(mode="after")
    def validate_port_range(self) -> SupplySyntheticSettings:
        if self.maximum_ports_per_charger < self.minimum_ports_per_charger:
            raise ValueError("maximum_ports_per_charger cannot be smaller than the minimum")
        return self


class BehaviourSyntheticSettings(StrictConfigModel):
    recommendations_per_request: int = Field(default=5, gt=0, le=20)
    selection_probability: float = Field(default=0.78, ge=0, le=1)
    cancellation_probability: float = Field(default=0.08, ge=0, le=1)
    no_show_probability: float = Field(default=0.07, ge=0, le=1)
    maximum_queue_wait_minutes: int = Field(default=45, gt=0, le=180)
    session_duration_log_sigma: float = Field(default=0.28, gt=0, le=1)

    @model_validator(mode="after")
    def validate_outcome_probabilities(self) -> BehaviourSyntheticSettings:
        if self.cancellation_probability + self.no_show_probability >= 1:
            raise ValueError("cancellation and no-show probabilities must sum to less than 1")
        return self


class SyntheticSafeguards(StrictConfigModel):
    maximum_generated_rows: int = Field(gt=0)
    require_reproducible_manifest: bool = True
    keep_latent_variables_out_of_features: bool = True


class SyntheticSettings(StrictConfigModel):
    profile_name: str
    generator_version: str
    start_date: date
    days: int = Field(gt=0)
    zone_count: int = Field(gt=0)
    business_count: int = Field(gt=0)
    charger_count: int = Field(gt=0)
    driver_count: int = Field(gt=0)
    scenario_mix: dict[str, float]
    demand: DemandSyntheticSettings
    availability: AvailabilitySyntheticSettings
    supply: SupplySyntheticSettings
    behaviour: BehaviourSyntheticSettings
    safeguards: SyntheticSafeguards

    @model_validator(mode="after")
    def validate_scenario_mix(self) -> SyntheticSettings:
        total_probability = sum(self.scenario_mix.values())
        if any(probability < 0 for probability in self.scenario_mix.values()):
            raise ValueError("scenario probabilities cannot be negative")
        if abs(total_probability - 1.0) > 1e-9:
            raise ValueError(
                f"scenario probabilities must sum to 1.0, received {total_probability}"
            )
        if self.charger_count < self.business_count:
            raise ValueError("charger_count must be at least business_count in pune_v1")
        return self


class VoltEZConfig(StrictConfigModel):
    project: ProjectSettings
    experiment: ExperimentSettings
    paths: PathSettings
    execution: ExecutionSettings
    time: TimeSettings
    data: DataSettings
    features: FeatureSettings
    environment: EnvironmentSettings
    synthetic: SyntheticSettings


def _read_yaml(path: Path) -> dict[str, Any]:
    """Read one YAML mapping and fail with a useful message for invalid files."""

    if not path.is_file():
        raise FileNotFoundError(f"configuration file not found: {path}")

    with path.open("r", encoding="utf-8") as stream:
        parsed = yaml.safe_load(stream)

    if not isinstance(parsed, dict):
        raise ValueError(f"configuration root must be a mapping: {path}")

    return parsed


def _deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    """Recursively merge nested mappings without changing the input dictionaries."""

    result = deepcopy(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = _deep_merge(result[key], value)
        else:
            result[key] = deepcopy(value)
    return result


def load_config(
    environment: Literal["development", "test"] = "development",
    synthetic_profile: str = "pune_v1",
    project_root: Path | None = None,
    experiment_profile: str | None = None,
) -> VoltEZConfig:
    """Load validated base, environment, synthetic, and optional experiment settings."""

    root = project_root or Path(__file__).resolve().parents[2]
    base = _read_yaml(root / "configs" / "base.yaml")
    environment_values = _read_yaml(root / "configs" / "environments" / f"{environment}.yaml")
    synthetic_values = _read_yaml(root / "configs" / "synthetic" / f"{synthetic_profile}.yaml")

    merged = _deep_merge(base, environment_values)
    merged = _deep_merge(merged, synthetic_values)
    if experiment_profile is not None:
        experiment_values = _read_yaml(
            root / "configs" / "experiments" / f"{experiment_profile}.yaml"
        )
        merged = _deep_merge(merged, experiment_values)
    return VoltEZConfig.model_validate(merged)
