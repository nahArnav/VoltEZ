"""Leakage-safe demand forecasting feature construction."""

from __future__ import annotations

import math
from typing import Any, cast

import numpy as np
import pandas as pd

from voltez_ml.config import VoltEZConfig
from voltez_ml.geography import nearest_neighbor_ids

ZONE_TYPES = (
    "commercial",
    "industrial",
    "mixed",
    "office",
    "residential",
    "retail",
    "transit",
)


def _safe_feature_suffix(value: str) -> str:
    """Convert a controlled category into a stable numeric feature-column suffix."""

    return "".join(character if character.isalnum() else "_" for character in value.casefold())


def _expand_context_event_days(context_events: pd.DataFrame) -> pd.DataFrame:
    """Expand scheduled intervals to local days without expanding them to every 15-minute row."""

    if context_events.empty:
        return context_events.assign(_target_day=pd.Series(dtype="datetime64[ns]"))
    events = context_events.copy()
    events["starts_at"] = pd.to_datetime(events["starts_at"])
    events["ends_at"] = pd.to_datetime(events["ends_at"])
    events["published_at"] = pd.to_datetime(events["published_at"])
    events["ingested_at"] = pd.to_datetime(events["ingested_at"])
    events["_target_day"] = [
        list(
            pd.date_range(
                starts_at.normalize(),
                (ends_at - pd.Timedelta(1, unit="ns")).normalize(),
                freq="D",
            )
        )
        for starts_at, ends_at in zip(events["starts_at"], events["ends_at"], strict=True)
    ]
    return events.explode("_target_day", ignore_index=True)


def _add_context_features(
    config: VoltEZConfig,
    horizon: pd.DataFrame,
    context_events: pd.DataFrame | None,
) -> pd.DataFrame:
    """Attach target-time events only when they were known by the prediction origin."""

    event_types = tuple(
        event_type for event_type in config.synthetic.scenario_mix if event_type != "normal_weekday"
    )
    result = horizon.copy()
    result["context_event_count"] = 0
    result["context_expected_impact_sum"] = 0.0
    result["context_expected_impact_max"] = 0.0
    for event_type in event_types:
        result[f"context_event_{_safe_feature_suffix(event_type)}"] = 0
    if context_events is None or context_events.empty:
        return result

    result["_feature_row_id"] = np.arange(len(result), dtype="int64")
    result["_target_day"] = pd.to_datetime(result["target_time"]).dt.normalize()
    expanded = _expand_context_event_days(context_events)
    candidates = result[
        [
            "_feature_row_id",
            "simulation_run_id",
            "zone_id",
            "prediction_origin",
            "target_time",
            "_target_day",
        ]
    ].merge(
        expanded[
            [
                "simulation_run_id",
                "zone_id",
                "event_type",
                "starts_at",
                "ends_at",
                "expected_impact",
                "published_at",
                "ingested_at",
                "_target_day",
            ]
        ],
        on=["simulation_run_id", "zone_id", "_target_day"],
        how="left",
        sort=False,
    )
    known = (
        candidates["starts_at"].notna()
        & (candidates["starts_at"] <= candidates["target_time"])
        & (candidates["target_time"] < candidates["ends_at"])
        & (candidates["published_at"] <= candidates["prediction_origin"])
        & (candidates["ingested_at"] <= candidates["prediction_origin"])
    )
    candidates["_known"] = known.astype("int8")
    candidates["_known_impact"] = candidates["expected_impact"].where(known)
    available_at = candidates[["published_at", "ingested_at"]].max(axis=1)
    candidates["_context_available_at"] = available_at.where(known)
    for event_type in event_types:
        candidates[f"context_event_{_safe_feature_suffix(event_type)}"] = (
            known & candidates["event_type"].eq(event_type)
        ).astype("int8")

    aggregations: dict[str, tuple[str, str]] = {
        "context_event_count": ("_known", "sum"),
        "context_expected_impact_sum": ("_known_impact", "sum"),
        "context_expected_impact_max": ("_known_impact", "max"),
        "_context_available_at": ("_context_available_at", "max"),
    }
    aggregations.update(
        {
            f"context_event_{_safe_feature_suffix(event_type)}": (
                f"context_event_{_safe_feature_suffix(event_type)}",
                "max",
            )
            for event_type in event_types
        }
    )
    features = candidates.groupby("_feature_row_id", sort=False).agg(**aggregations)
    result = result.drop(
        columns=[
            "context_event_count",
            "context_expected_impact_sum",
            "context_expected_impact_max",
            *(f"context_event_{_safe_feature_suffix(value)}" for value in event_types),
        ]
    ).merge(features, left_on="_feature_row_id", right_index=True, validate="one_to_one")
    result["context_expected_impact_sum"] = pd.to_numeric(
        result["context_expected_impact_sum"], errors="coerce"
    ).fillna(0.0)
    result["context_expected_impact_max"] = pd.to_numeric(
        result["context_expected_impact_max"], errors="coerce"
    ).fillna(0.0)
    evidence_known = result["_context_available_at"].notna()
    later_evidence = evidence_known & (
        result["_context_available_at"] > result["latest_source_time"]
    )
    result.loc[later_evidence, "latest_source_time"] = result.loc[
        later_evidence, "_context_available_at"
    ]
    return result.drop(columns=["_feature_row_id", "_target_day", "_context_available_at"])


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
    context_events: pd.DataFrame | None = None,
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
            "zone_type",
        ]
    ]
    history = history.merge(zone_columns, on=keys, how="left", validate="many_to_one")
    history["zone_type_unknown"] = (~history["zone_type"].isin(ZONE_TYPES)).astype("int8")
    for zone_type in ZONE_TYPES:
        history[f"zone_type_{zone_type}"] = history["zone_type"].eq(zone_type).astype("int8")

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
        horizon_buckets = horizon_minutes // bucket_minutes
        horizon_group = horizon.groupby(keys, sort=False)
        horizon["request_lag_target_time_yesterday"] = horizon_group["request_count"].shift(
            buckets_per_day - horizon_buckets
        )
        horizon["request_lag_target_time_last_week"] = horizon_group["request_count"].shift(
            buckets_per_week - horizon_buckets
        )
        horizon["missing_target_lag_yesterday"] = (
            horizon["request_lag_target_time_yesterday"].isna().astype("int8")
        )
        horizon["missing_target_lag_last_week"] = (
            horizon["request_lag_target_time_last_week"].isna().astype("int8")
        )
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
        horizon = _add_context_features(config, horizon, context_events)
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
        "zone_type",
    }
    return (
        result.drop(columns=[column for column in passthrough if column in result.columns])
        .sort_values(
            ["simulation_run_id", "prediction_origin", "zone_id", "horizon_minutes"],
            kind="mergesort",
        )
        .reset_index(drop=True)
    )
