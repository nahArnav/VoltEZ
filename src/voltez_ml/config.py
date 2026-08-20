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
                "demand horizons must be positive multiples of bucket_minutes: "
                f"{invalid_horizons}"
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
    paths: PathSettings
    execution: ExecutionSettings
    time: TimeSettings
    data: DataSettings
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
) -> VoltEZConfig:
    """Load base, environment, and synthetic profile settings into one validated object."""

    root = project_root or Path(__file__).resolve().parents[2]
    base = _read_yaml(root / "configs" / "base.yaml")
    environment_values = _read_yaml(root / "configs" / "environments" / f"{environment}.yaml")
    synthetic_values = _read_yaml(root / "configs" / "synthetic" / f"{synthetic_profile}.yaml")

    merged = _deep_merge(base, environment_values)
    merged = _deep_merge(merged, synthetic_values)
    return VoltEZConfig.model_validate(merged)
