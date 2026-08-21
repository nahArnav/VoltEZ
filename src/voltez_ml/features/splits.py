"""Chronological and cross-seed holdout assignment."""

from __future__ import annotations

from typing import Any

import pandas as pd

from voltez_ml.config import SplitSettings


def assign_purged_temporal_splits(
    frame: pd.DataFrame,
    settings: SplitSettings,
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
    if len(run_ids) >= 3:
        test_run = run_ids[-1]
        validation_run = run_ids[-2]
        result["run_holdout_split"] = (
            result["simulation_run_id"]
            .astype(str)
            .map(
                lambda run_id: (
                    "test"
                    if run_id == test_run
                    else "validation"
                    if run_id == validation_run
                    else "train"
                )
            )
        )
        report["cross_seed"] = {
            "available": True,
            "validation_run": validation_run,
            "test_run": test_run,
        }
    else:
        result["run_holdout_split"] = "not_available"
        report["cross_seed"] = {
            "available": False,
            "reason": "generate at least three independently seeded runs",
        }
    return result.reset_index(drop=True), report
