"""Chronological and cross-seed holdout assignment."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

import pandas as pd

from voltez_ml.config import SplitSettings


def assign_purged_temporal_splits(
    frame: pd.DataFrame,
    settings: SplitSettings,
    run_roles: Mapping[str, str] | None = None,
) -> tuple[pd.DataFrame, dict[str, Any]]:
    """Assign train/validation/test without letting targets cross time boundaries."""

    assigned: list[pd.DataFrame] = []
    report: dict[str, Any] = {"runs": {}, "purged_rows": 0}
    for run_id, group in frame.groupby("simulation_run_id", sort=True):
        origins = group["prediction_origin"].drop_duplicates().sort_values().tolist()
        if len(origins) < 3:
            raise ValueError(f"run {run_id} needs at least three distinct prediction origins")
        first_index = min(
            max(1, int(len(origins) * settings.train_fraction)),
            len(origins) - 2,
        )
        second_index = min(
            max(
                first_index + 1,
                int(len(origins) * (settings.train_fraction + settings.validation_fraction)),
            ),
            len(origins) - 1,
        )
        validation_start = pd.Timestamp(origins[first_index])
        test_start = pd.Timestamp(origins[second_index])
        run_group = group.copy()
        train_mask = (run_group["prediction_origin"] < validation_start) & (
            run_group["target_time"] < validation_start
        )
        validation_mask = (
            (run_group["prediction_origin"] >= validation_start)
            & (run_group["prediction_origin"] < test_start)
            & (run_group["target_time"] < test_start)
        )
        test_mask = run_group["prediction_origin"] >= test_start
        run_group["split"] = pd.NA
        run_group.loc[train_mask, "split"] = "train"
        run_group.loc[validation_mask, "split"] = "validation"
        run_group.loc[test_mask, "split"] = "test"
        purged = int(run_group["split"].isna().sum())
        report["purged_rows"] += purged
        report["runs"][str(run_id)] = {
            "validation_start": validation_start.isoformat(),
            "test_start": test_start.isoformat(),
            "purged_rows": purged,
        }
        assigned.append(run_group[run_group["split"].notna()])
    result = pd.concat(assigned, ignore_index=True)
    run_ids = sorted(result["simulation_run_id"].astype(str).unique())
    normalized_roles = {
        run_id: str((run_roles or {}).get(run_id, "development")) for run_id in run_ids
    }
    declared_roles = {
        run_id: role for run_id, role in normalized_roles.items() if role != "development"
    }
    required_roles = {"train", "validation", "test"}
    if declared_roles:
        if len(declared_roles) != len(run_ids):
            missing = sorted(set(run_ids) - set(declared_roles))
            raise ValueError(
                "declared experiment roles cannot be mixed with development runs; "
                f"missing explicit roles for {missing}"
            )
        invalid = set(declared_roles.values()) - required_roles - {"stress_test"}
        if invalid:
            raise ValueError(f"unsupported experiment roles in source manifests: {sorted(invalid)}")
        result["run_holdout_split"] = result["simulation_run_id"].astype(str).map(
            declared_roles
        )
        present_roles = set(declared_roles.values())
        report["cross_seed"] = {
            "available": required_roles.issubset(present_roles),
            "assignment_source": "declared_experiment_roles",
            "run_roles": declared_roles,
        }
        if not report["cross_seed"]["available"]:
            report["cross_seed"]["reason"] = (
                "declared runs must include train, validation, and test roles"
            )
    else:
        result["run_holdout_split"] = "not_available"
        report["cross_seed"] = {
            "available": False,
            "assignment_source": "not_available",
            "reason": (
                "generate independently seeded runs with explicit train, validation, and test "
                "experiment roles"
            ),
        }
    return result.reset_index(drop=True), report
