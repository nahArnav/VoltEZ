"""Feature leakage, consistency, and distribution audits."""

from __future__ import annotations

from typing import Any

import numpy as np
import pandas as pd


def _time_failures(frame: pd.DataFrame, table_name: str) -> list[str]:
    failures: list[str] = []
    if bool((frame["feature_cutoff"] > frame["prediction_origin"]).any()):
        failures.append(f"{table_name}: feature cutoff occurs after prediction origin")
    if bool((frame["latest_source_time"] > frame["prediction_origin"]).any()):
        failures.append(f"{table_name}: a feature source occurs after prediction origin")
    if bool((frame["target_time"] <= frame["prediction_origin"]).any()):
        failures.append(f"{table_name}: target must be later than prediction origin")
    return failures


def _split_failures(frame: pd.DataFrame, table_name: str) -> list[str]:
    failures: list[str] = []
    for run_id, group in frame.groupby("simulation_run_id", sort=False):
        train = group[group["split"] == "train"]
        validation = group[group["split"] == "validation"]
        test = group[group["split"] == "test"]
        if train.empty or validation.empty or test.empty:
            failures.append(f"{table_name}/{run_id}: one temporal split is empty")
            continue
        if train["target_time"].max() >= validation["prediction_origin"].min():
            failures.append(f"{table_name}/{run_id}: train targets overlap validation origins")
        if validation["target_time"].max() >= test["prediction_origin"].min():
            failures.append(f"{table_name}/{run_id}: validation targets overlap test origins")
    return failures


def _missingness(frame: pd.DataFrame) -> dict[str, float]:
    return {
        str(column): round(float(rate), 6)
        for column, rate in frame.isna().mean().items()
        if rate > 0
    }


def _constant_columns(frame: pd.DataFrame) -> list[str]:
    ignored = {
        "simulation_run_id",
        "source_snapshot_id",
        "feature_cutoff",
        "split",
        "run_holdout_split",
    }
    return sorted(
        column
        for column in frame.columns
        if column not in ignored and frame[column].nunique(dropna=False) <= 1
    )


def audit_feature_tables(
    demand: pd.DataFrame,
    availability_all: pd.DataFrame,
    availability_labeled: pd.DataFrame,
    demand_split_report: dict[str, Any],
    availability_split_report: dict[str, Any],
) -> dict[str, Any]:
    """Return a JSON-ready audit and fail callers when a hard invariant is violated."""

    failures = [
        *_time_failures(demand, "demand_features"),
        *_time_failures(availability_all, "availability_features"),
        *_split_failures(demand, "demand_features"),
        *_split_failures(availability_labeled, "availability_features_labeled"),
    ]
    warnings: list[str] = []
    forbidden_columns = [
        column
        for frame in (demand, availability_all)
        for column in frame.columns
        if column.startswith("latent_") or column.startswith("qa_latent_")
    ]
    if forbidden_columns:
        failures.append(f"latent columns leaked into feature output: {sorted(forbidden_columns)}")
    demand_key = [
        "simulation_run_id",
        "zone_id",
        "prediction_origin",
        "target_time",
        "horizon_minutes",
    ]
    availability_key = ["simulation_run_id", "observation_id"]
    if bool(demand.duplicated(demand_key).any()):
        failures.append("demand feature keys are not unique")
    if bool(availability_all.duplicated(availability_key).any()):
        failures.append("availability feature keys are not unique")
    if bool((demand["target_request_count"] < 0).any()):
        failures.append("demand target contains negative counts")
    if set(availability_all["label"].astype(str)) - {
        "available",
        "unavailable",
        "unknown",
    }:
        failures.append("availability feature labels have an invalid state")
    if bool((availability_labeled["label"] == "unknown").any()):
        failures.append("unknown availability leaked into supervised rows")
    expected_labeled = int((availability_all["label"] != "unknown").sum())
    if len(availability_labeled) != expected_labeled:
        failures.append("labeled availability output does not match known-label count")
    for source_column in (
        "latest_booking_event_at",
        "latest_session_event_at",
        "status_ingested_at_feature",
        "demand_cutoff_at",
    ):
        known = availability_all[source_column].notna()
        if bool(
            (
                availability_all.loc[known, source_column]
                > availability_all.loc[known, "prediction_origin"]
            ).any()
        ):
            failures.append(f"availability source {source_column} occurs after origin")

    numeric_candidates = demand.select_dtypes(include=[np.number]).columns
    for column in numeric_candidates:
        if column in {"target_request_count", "horizon_minutes"}:
            continue
        if demand[column].equals(demand["target_request_count"]):
            failures.append(f"demand feature {column} exactly equals its target")
    if not demand_split_report["cross_seed"]["available"]:
        warnings.append(
            "cross-seed holdout is unavailable; declare independent train, validation, and test "
            "seed roles before model claims"
        )
    if not availability_split_report["cross_seed"]["available"]:
        warnings.append(
            "availability cross-seed holdout is unavailable; explicit train, validation, and "
            "test seed roles are required"
        )
    label_distribution = availability_labeled["label"].value_counts().to_dict()
    if len(label_distribution) < 2:
        warnings.append("availability supervised data contains only one class")
    elif min(label_distribution.values()) / sum(label_distribution.values()) < 0.05:
        warnings.append("availability minority class is below 5%; use class-aware evaluation")

    report = {
        "status": "failed" if failures else "passed_with_warnings" if warnings else "passed",
        "failures": failures,
        "warnings": warnings,
        "demand": {
            "rows": len(demand),
            "target_mean": float(demand["target_request_count"].mean()),
            "target_variance": float(demand["target_request_count"].var()),
            "zero_target_rate": float((demand["target_request_count"] == 0).mean()),
            "rows_by_split": demand["split"].value_counts().to_dict(),
            "rows_by_horizon": demand["horizon_minutes"].value_counts().sort_index().to_dict(),
            "missingness": _missingness(demand),
            "constant_columns": _constant_columns(demand),
        },
        "availability": {
            "all_rows": len(availability_all),
            "labeled_rows": len(availability_labeled),
            "label_distribution": label_distribution,
            "unknown_rate": float((availability_all["label"] == "unknown").mean()),
            "rows_by_split": availability_labeled["split"].value_counts().to_dict(),
            "cold_start_rate": float(availability_all["cold_start"].mean()),
            "status_missing_rate": float(availability_all["status_missing"].mean()),
            "missingness": _missingness(availability_all),
            "constant_columns": _constant_columns(availability_all),
        },
        "splits": {
            "demand": demand_split_report,
            "availability": availability_split_report,
        },
    }
    return report
