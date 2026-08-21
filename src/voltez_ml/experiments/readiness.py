"""Validate a multi-seed data plan before expensive generation begins."""

from __future__ import annotations

from collections import Counter
from pathlib import Path
from typing import Any, Literal

from voltez_ml.config import VoltEZConfig, load_config
from voltez_ml.synthetic.randomness import config_fingerprint
from voltez_ml.synthetic.validation import estimate_planned_rows

DEFAULT_EXPERIMENT_PROFILES = (
    "train_seed_01",
    "train_seed_02",
    "validation_seed_01",
    "test_seed_01",
    "stress_seed_01",
)

# DataFrame memory varies greatly by dtype. This is deliberately conservative and is only a
# preflight ceiling; actual peak resident memory will be measured during the small rehearsal.
PLANNING_BYTES_PER_ROW = 2_500


def _baseline_distribution_fingerprint(config: VoltEZConfig) -> str:
    """Hash only settings that must match across headline train/validation/test runs."""

    values = {
        "city": config.project.city,
        "timezone": config.project.timezone,
        "time": config.time.model_dump(mode="json"),
        "feature_view_version": config.data.feature_view_version,
        "label_definition_version": config.data.label_definition_version,
        "synthetic": config.synthetic.model_dump(mode="json"),
    }
    return config_fingerprint(values)


def _memory_gb(rows: int) -> float:
    return round(rows * PLANNING_BYTES_PER_ROW / (1024**3), 3)


def _generation_command(
    environment: Literal["development", "test"],
    synthetic_profile: str,
    experiment_profile: str,
) -> str:
    return (
        f"uv run voltez-generate --environment {environment} "
        f"--profile {synthetic_profile} --experiment {experiment_profile}"
    )


def build_data_readiness_report(
    project_root: Path,
    synthetic_profile: str = "pune_v1",
    experiment_profiles: tuple[str, ...] = DEFAULT_EXPERIMENT_PROFILES,
    environment: Literal["development", "test"] = "development",
) -> dict[str, Any]:
    """Return a JSON-ready go/no-go report; this function never generates data."""

    failures: list[str] = []
    warnings: list[str] = []
    if not experiment_profiles:
        failures.append("at least one experiment profile is required")
    if len(experiment_profiles) != len(set(experiment_profiles)):
        failures.append("experiment profile names must be unique")

    configs = [
        load_config(
            environment=environment,
            synthetic_profile=synthetic_profile,
            experiment_profile=profile,
            project_root=project_root,
        )
        for profile in experiment_profiles
    ]
    seeds = [config.project.seed for config in configs]
    if len(seeds) != len(set(seeds)):
        failures.append("every experiment profile must use an independent seed")

    role_counts = Counter(config.experiment.evaluation_role for config in configs)
    if role_counts["train"] < 2:
        failures.append("at least two independent training seeds are required")
    if role_counts["validation"] != 1:
        failures.append("exactly one validation seed is required")
    if role_counts["test"] != 1:
        failures.append("exactly one locked test seed is required")
    if role_counts["development"]:
        failures.append("development-role runs cannot enter the canonical training plan")
    if role_counts["stress_test"] == 0:
        warnings.append("no stress-test seed is planned")

    baseline_configs = [
        config
        for config in configs
        if config.experiment.evaluation_role in {"train", "validation", "test"}
    ]
    baseline_fingerprints = {
        _baseline_distribution_fingerprint(config) for config in baseline_configs
    }
    if len(baseline_fingerprints) > 1:
        failures.append(
            "train, validation, and test runs must share one baseline data distribution"
        )

    stress_configs = [
        config for config in configs if config.experiment.evaluation_role == "stress_test"
    ]
    if stress_configs and baseline_configs:
        baseline_fingerprint = _baseline_distribution_fingerprint(baseline_configs[0])
        if all(
            _baseline_distribution_fingerprint(config) == baseline_fingerprint
            for config in stress_configs
        ):
            warnings.append("stress-test distribution is identical to the baseline distribution")

    run_plans: list[dict[str, Any]] = []
    for profile, config in zip(experiment_profiles, configs, strict=True):
        if config.experiment.name != profile:
            failures.append(
                f"{profile} declares mismatched experiment name {config.experiment.name}"
            )
        estimated_rows = estimate_planned_rows(config)
        maximum_rows = config.synthetic.safeguards.maximum_generated_rows
        if estimated_rows > maximum_rows:
            failures.append(
                f"{profile} estimates {estimated_rows} rows above its {maximum_rows} ceiling"
            )
        run_plans.append(
            {
                "experiment_profile": profile,
                "experiment_name": config.experiment.name,
                "evaluation_role": config.experiment.evaluation_role,
                "seed": config.project.seed,
                "days": config.synthetic.days,
                "estimated_rows": estimated_rows,
                "row_safety_ceiling": maximum_rows,
                "estimated_peak_memory_gb": _memory_gb(estimated_rows),
                "scenario_mix": config.synthetic.scenario_mix,
                "generation_command": _generation_command(
                    environment, synthetic_profile, profile
                ),
            }
        )

    baseline_rows = sum(
        int(plan["estimated_rows"])
        for plan in run_plans
        if plan["evaluation_role"] != "stress_test"
    )
    largest_run_rows = max((int(plan["estimated_rows"]) for plan in run_plans), default=0)
    memory_budget_gb = configs[0].execution.memory_budget_gb if configs else 0.0
    generation_peak_gb = _memory_gb(largest_run_rows)
    combined_baseline_gb = _memory_gb(baseline_rows)
    if generation_peak_gb > memory_budget_gb:
        failures.append(
            "conservative single-run memory estimate exceeds the configured memory budget"
        )
    if combined_baseline_gb > memory_budget_gb:
        warnings.append(
            "combined baseline feature build may exceed memory budget; benchmark the rehearsal "
            "and use staged/streaming feature assembly if needed"
        )

    return {
        "status": "not_ready" if failures else "ready_with_warnings" if warnings else "ready",
        "generates_data": False,
        "trains_models": False,
        "synthetic_profile": synthetic_profile,
        "failures": failures,
        "warnings": warnings,
        "role_counts": dict(sorted(role_counts.items())),
        "resource_plan": {
            "machine": "Apple Silicon M4 / 16 GB RAM",
            "configured_memory_budget_gb": memory_budget_gb,
            "planning_bytes_per_row": PLANNING_BYTES_PER_ROW,
            "sequential_generation_peak_estimate_gb": generation_peak_gb,
            "combined_baseline_feature_estimate_gb": combined_baseline_gb,
            "generation_policy": "generate and validate one run at a time",
        },
        "evaluation_policy": {
            "fit_models_on": ["train"],
            "choose_hyperparameters_on": ["validation"],
            "unlock_once_for_final_metrics": ["test"],
            "robustness_only_not_headline_metrics": ["stress_test"],
        },
        "runs": run_plans,
    }
