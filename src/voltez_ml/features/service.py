"""Leakage-safe feature views for waiting time and charger reliability."""

from __future__ import annotations

from bisect import bisect_left, bisect_right
from typing import Any, cast

import numpy as np
import pandas as pd

from voltez_ml.config import VoltEZConfig


def _records(frame: pd.DataFrame) -> list[dict[str, Any]]:
    return cast(list[dict[str, Any]], frame.to_dict("records"))


def _base_without_availability_label(availability: pd.DataFrame) -> pd.DataFrame:
    return availability.rename(
        columns={"observation_id": "availability_observation_id"}
    ).drop(
        columns=["label", "label_known", "label_source", "label_confidence", "target_time"]
    )


def _waiting_history(
    config: VoltEZConfig,
    frame: pd.DataFrame,
    observations: pd.DataFrame,
) -> pd.DataFrame:
    history: dict[tuple[str, str], tuple[list[pd.Timestamp], list[float]]] = {}
    known = observations[
        (observations["label_known"] == 1) & observations["label_observed_at"].notna()
    ]
    for (run_id, port_id), group in known.sort_values("label_observed_at").groupby(
        ["simulation_run_id", "port_id"], sort=False
    ):
        history[(str(run_id), str(port_id))] = (
            [pd.Timestamp(value) for value in group["label_observed_at"]],
            [float(value) for value in group["label_wait_minutes"]],
        )

    window = pd.to_timedelta(config.features.waiting_history_hours, unit="h")
    counts: list[int] = []
    means: list[float] = []
    positive_rates: list[float] = []
    latest_times: list[pd.Timestamp | None] = []
    for row in _records(frame):
        origin = pd.Timestamp(row["prediction_origin"])
        key = (str(row["simulation_run_id"]), str(row["port_id"]))
        times, values = history.get(key, ([], []))
        lower = bisect_left(times, origin - window)
        upper = bisect_right(times, origin)
        prior = values[lower:upper]
        counts.append(len(prior))
        means.append(float(np.mean(prior)) if prior else np.nan)
        positive_rates.append(
            float(np.mean(np.asarray(prior) > 0)) if prior else np.nan
        )
        latest_times.append(times[upper - 1] if upper > lower else None)
    enriched = frame.copy()
    enriched["prior_wait_observation_count"] = counts
    enriched["prior_mean_queue_wait_minutes"] = means
    enriched["prior_positive_wait_rate"] = positive_rates
    enriched["waiting_history_missing"] = (
        enriched["prior_wait_observation_count"] == 0
    ).astype(int)
    enriched["latest_wait_observed_at_feature"] = latest_times
    known_latest = enriched["latest_wait_observed_at_feature"].notna()
    enriched.loc[known_latest, "latest_source_time"] = enriched.loc[known_latest, [
        "latest_source_time",
        "latest_wait_observed_at_feature",
    ]].max(axis=1)
    return enriched


def build_waiting_time_features(
    config: VoltEZConfig,
    availability_features: pd.DataFrame,
    waiting_observations: pd.DataFrame,
) -> pd.DataFrame:
    """Build Model 3 rows; the target is queue time until the reserved port is service-ready."""

    keys = ["simulation_run_id", "request_id", "port_id"]
    observation_columns = [
        *keys,
        "waiting_observation_id",
        "booking_id",
        "session_id",
        "target_arrival_at",
        "actual_arrival_at",
        "label_wait_minutes",
        "label_known",
        "label_source",
        "label_observed_at",
        "outcome",
        "prediction_origin",
        "feature_cutoff",
    ]
    frame = waiting_observations[observation_columns].rename(
        columns={
            "prediction_origin": "observation_prediction_origin",
            "feature_cutoff": "observation_feature_cutoff",
        }
    ).merge(
        _base_without_availability_label(availability_features),
        on=keys,
        how="left",
        validate="one_to_one",
    )
    if bool(frame["availability_observation_id"].isna().any()):
        raise ValueError("a waiting-time observation has no causal candidate feature row")
    if bool(
        (frame["observation_prediction_origin"] != frame["prediction_origin"]).any()
        or (frame["observation_feature_cutoff"] != frame["feature_cutoff"]).any()
    ):
        raise ValueError("waiting-time observation cutoff disagrees with its candidate features")
    frame = frame.drop(
        columns=["observation_prediction_origin", "observation_feature_cutoff"]
    )
    frame["target_time"] = frame["label_observed_at"].fillna(frame["target_arrival_at"])
    frame = _waiting_history(config, frame, waiting_observations)
    return frame.sort_values(
        ["simulation_run_id", "prediction_origin", "request_id", "port_id"],
        kind="mergesort",
    ).reset_index(drop=True)


def build_reliability_features(
    availability_features: pd.DataFrame,
    reliability_observations: pd.DataFrame,
) -> pd.DataFrame:
    """Build Model 4 rows while excluding congestion failures from hardware truth."""

    keys = ["simulation_run_id", "request_id", "port_id"]
    observation_columns = [
        *keys,
        "reliability_observation_id",
        "booking_id",
        "session_id",
        "target_arrival_at",
        "label",
        "label_known",
        "label_source",
        "label_observed_at",
        "failure_reason",
        "prediction_origin",
        "feature_cutoff",
    ]
    frame = reliability_observations[observation_columns].rename(
        columns={
            "failure_reason": "label_failure_reason",
            "prediction_origin": "observation_prediction_origin",
            "feature_cutoff": "observation_feature_cutoff",
        }
    ).merge(
        _base_without_availability_label(availability_features),
        on=keys,
        how="left",
        validate="one_to_one",
    )
    if bool(frame["availability_observation_id"].isna().any()):
        raise ValueError("a reliability observation has no causal candidate feature row")
    if bool(
        (frame["observation_prediction_origin"] != frame["prediction_origin"]).any()
        or (frame["observation_feature_cutoff"] != frame["feature_cutoff"]).any()
    ):
        raise ValueError("reliability observation cutoff disagrees with its candidate features")
    frame = frame.drop(
        columns=["observation_prediction_origin", "observation_feature_cutoff"]
    )
    frame["target_time"] = frame["label_observed_at"].fillna(frame["target_arrival_at"])
    return frame.sort_values(
        ["simulation_run_id", "prediction_origin", "request_id", "port_id"],
        kind="mergesort",
    ).reset_index(drop=True)
