"""Leakage-safe demand forecasting feature construction."""

from __future__ import annotations

import math
from typing import Any, cast

import numpy as np
import pandas as pd

from voltez_ml.config import VoltEZConfig
from voltez_ml.geography import nearest_neighbor_ids


def _neighbor_lag(
    history: pd.DataFrame,
    zones: pd.DataFrame,
) -> pd.Series:
    """Average the previous complete bucket from the two nearest zones."""

    pieces: list[pd.DataFrame] = []
    for run_id, run_zones in zones.groupby("simulation_run_id", sort=False):
        neighbors = nearest_neighbor_ids(
            cast(list[dict[str, Any]], run_zones.to_dict("records")),
            identifier_key="zone_id",
            latitude_key="centroid_latitude",
            longitude_key="centroid_longitude",
        )
        run_history = history[history["simulation_run_id"] == run_id][
            ["zone_id", "bucket_start", "request_lag_1"]
        ]
        for zone_id, neighbor_ids in neighbors.items():
            if not neighbor_ids:
                continue
            neighbor_values = run_history[run_history["zone_id"].isin(neighbor_ids)]
            averaged = neighbor_values.groupby("bucket_start", as_index=False).agg(
                neighbor_request_lag_1=("request_lag_1", "mean")
            )
            averaged["simulation_run_id"] = run_id
            averaged["zone_id"] = zone_id
            pieces.append(averaged)
    if not pieces:
        return pd.Series(np.nan, index=history.index, dtype="float64")
    lookup = pd.concat(pieces, ignore_index=True)
    joined = history[["simulation_run_id", "zone_id", "bucket_start"]].merge(
        lookup,
        on=["simulation_run_id", "zone_id", "bucket_start"],
        how="left",
        sort=False,
    )
    return joined["neighbor_request_lag_1"].set_axis(history.index)


def build_demand_features(
    config: VoltEZConfig,
    demand_buckets: pd.DataFrame,
    zones: pd.DataFrame,
) -> pd.DataFrame:
    """Build one causal row per zone, origin, target bucket, and forecast horizon."""

    bucket_minutes = config.time.bucket_minutes
    buckets_per_day = 24 * 60 // bucket_minutes
    buckets_per_week = 7 * buckets_per_day
    keys = ["simulation_run_id", "zone_id"]
    history = demand_buckets.sort_values([*keys, "bucket_start"], kind="mergesort").copy()
    group = history.groupby(keys, sort=False)

    # Shift first. Every statistic below is therefore based on buckets that ended before origin.
    history["request_lag_1"] = group["request_count"].shift(1)
    history["search_lag_1"] = group["search_count"].shift(1)
    history["unserved_lag_1"] = group["unserved_count"].shift(1)
    history["booking_lag_1"] = group["booking_count"].shift(1)
    history["session_lag_1"] = group["session_count"].shift(1)
    history["listed_ports_lag_1"] = group["compatible_ports_listed"].shift(1)
    history["available_ports_lag_1"] = group["compatible_ports_available"].shift(1)
    history["occupancy_lag_1"] = group["occupancy_rate"].shift(1)
    history["request_lag_same_time_yesterday"] = group["request_count"].shift(buckets_per_day)
    history["request_lag_same_time_last_week"] = group["request_count"].shift(buckets_per_week)
    history["missing_lag_yesterday"] = history["request_lag_same_time_yesterday"].isna().astype(int)
    history["missing_lag_last_week"] = history["request_lag_same_time_last_week"].isna().astype(int)

    shifted_requests = history["request_lag_1"]
    shifted_no_candidate = group["no_candidate_count"].shift(1)
    for window in config.features.demand_recent_windows_buckets:
        history[f"request_sum_prior_{window}_buckets"] = (
            shifted_requests.groupby([history[key] for key in keys], sort=False)
            .rolling(window, min_periods=1)
            .sum()
            .reset_index(level=[0, 1], drop=True)
        )
    rolling_window = max(config.features.demand_recent_windows_buckets)
    request_rolling = shifted_requests.groupby([history[key] for key in keys], sort=False).rolling(
        rolling_window, min_periods=2
    )
    history["request_mean_prior_window"] = request_rolling.mean().reset_index(
        level=[0, 1], drop=True
    )
    history["request_std_prior_window"] = request_rolling.std().reset_index(level=[0, 1], drop=True)
    history["request_ewm_prior"] = shifted_requests.groupby(
        [history[key] for key in keys], sort=False
    ).transform(
        lambda values: values.ewm(
            span=config.features.demand_ewm_span_buckets,
            adjust=False,
            min_periods=1,
        ).mean()
    )
    prior_request_hour = (
        shifted_requests.groupby([history[key] for key in keys], sort=False)
        .rolling(4, min_periods=1)
        .sum()
        .reset_index(level=[0, 1], drop=True)
    )
    prior_no_candidate_hour = (
        shifted_no_candidate.groupby([history[key] for key in keys], sort=False)
        .rolling(4, min_periods=1)
        .sum()
        .reset_index(level=[0, 1], drop=True)
    )
    history["no_candidate_rate_prior_hour"] = (
        prior_no_candidate_hour / prior_request_hour.replace(0, np.nan)
    ).fillna(0.0)
    history["neighbor_request_lag_1"] = _neighbor_lag(history, zones)
    history["history_bucket_count"] = group.cumcount()
    history["prediction_origin"] = history["bucket_start"]
    history["feature_cutoff"] = history["prediction_origin"]
    history["latest_source_time"] = history["prediction_origin"] - pd.to_timedelta(
        bucket_minutes, unit="m"
    )

    zone_columns = zones[
        [
            "simulation_run_id",
            "zone_id",
            "centroid_latitude",
            "centroid_longitude",
        ]
    ]
    history = history.merge(zone_columns, on=keys, how="left", validate="many_to_one")

    frames: list[pd.DataFrame] = []
    target_lookup = history[[*keys, "bucket_start", "request_count"]].rename(
        columns={
            "bucket_start": "target_time",
            "request_count": "target_request_count",
        }
    )
    for horizon_minutes in config.time.demand_horizons_minutes:
        horizon = history.copy()
        horizon["target_time"] = horizon["prediction_origin"] + pd.to_timedelta(
            horizon_minutes, unit="m"
        )
        horizon["horizon_minutes"] = horizon_minutes
        horizon = horizon.merge(
            target_lookup,
            on=[*keys, "target_time"],
            how="left",
            validate="many_to_one",
        )
        target_hour = horizon["target_time"].dt.hour + horizon["target_time"].dt.minute / 60
        target_day = horizon["target_time"].dt.dayofweek
        horizon["target_hour_sin"] = np.sin(2 * math.pi * target_hour / 24)
        horizon["target_hour_cos"] = np.cos(2 * math.pi * target_hour / 24)
        horizon["target_day_sin"] = np.sin(2 * math.pi * target_day / 7)
        horizon["target_day_cos"] = np.cos(2 * math.pi * target_day / 7)
        horizon["target_is_weekend"] = (target_day >= 5).astype(int)
        horizon = horizon[
            (horizon["history_bucket_count"] >= config.features.demand_minimum_history_buckets)
            & horizon["target_request_count"].notna()
        ]
        frames.append(horizon)

    result = pd.concat(frames, ignore_index=True)
    result["target_request_count"] = result["target_request_count"].astype("int64")
    passthrough = {
        "bucket_start",
        "bucket_minutes",
        "request_count",
        "search_count",
        "served_request_count",
        "no_candidate_count",
        "unserved_count",
        "booking_count",
        "session_count",
        "occupancy_rate",
        "compatible_ports_listed",
        "compatible_ports_available",
    }
    return (
        result.drop(columns=[column for column in passthrough if column in result.columns])
        .sort_values(
            ["simulation_run_id", "prediction_origin", "zone_id", "horizon_minutes"],
            kind="mergesort",
        )
        .reset_index(drop=True)
    )
