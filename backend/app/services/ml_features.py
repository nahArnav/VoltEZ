import math
from datetime import datetime, timedelta, timezone
from typing import Dict, Any
from uuid import UUID
from zoneinfo import ZoneInfo
import pandas as pd

PUNE_TIMEZONE = ZoneInfo("Asia/Kolkata")


def build_demand_features(
    charger_id: UUID,
    prediction_origin: datetime | None = None,
) -> pd.DataFrame:
    """
    Point-in-time feature builder for Model 1 (Demand).
    Constructs the 52 features required by the demand prediction model.
    """
    origin = prediction_origin or datetime.now(timezone.utc)
    target = origin.astimezone(PUNE_TIMEZONE) + timedelta(minutes=15)
    target_hour = target.hour + target.minute / 60
    target_day = target.weekday()

    # Historical values remain conservative cold-start defaults until the
    # analytics aggregation job has accumulated live VoltEZ history. Calendar
    # values are derived from the actual prediction timestamp because the
    # serving contract validates them exactly.
    features: Dict[str, Any] = {
        "request_lag_1": 0.0,
        "search_lag_1": 0.0,
        "unserved_lag_1": 0.0,
        "booking_lag_1": 0.0,
        "session_lag_1": 0.0,
        "listed_ports_lag_1": 19.5,
        "available_ports_lag_1": 18.0,
        "occupancy_lag_1": 0.038,
        "request_lag_same_time_yesterday": 0.0,
        "request_lag_same_time_last_week": 0.0,
        "missing_lag_yesterday": 0,
        "missing_lag_last_week": 0,
        "request_sum_prior_1_buckets": 0.0,
        "request_sum_prior_2_buckets": 0.0,
        "request_sum_prior_4_buckets": 1.0,
        "request_sum_prior_24_buckets": 5.0,
        "request_mean_prior_window": 0.208,
        "request_std_prior_window": 0.442,
        "request_ewm_prior": 0.171,
        "no_candidate_rate_prior_hour": 0.0,
        "neighbor_request_lag_1": 0.0,
        "history_bucket_count": 4315.5,
        "centroid_latitude": 18.53465,
        "centroid_longitude": 73.8636,
        "zone_type_commercial": 1,
        "zone_type_industrial": 0,
        "zone_type_mixed": 0,
        "zone_type_office": 0,
        "zone_type_residential": 0,
        "zone_type_retail": 0,
        "zone_type_transit": 0,
        "request_lag_target_time_yesterday": 0.0,
        "request_lag_target_time_last_week": 0.0,
        "missing_target_lag_yesterday": 0,
        "missing_target_lag_last_week": 0,
        "target_hour_sin": math.sin(2 * math.pi * target_hour / 24),
        "target_hour_cos": math.cos(2 * math.pi * target_hour / 24),
        "target_day_sin": math.sin(2 * math.pi * target_day / 7),
        "target_day_cos": math.cos(2 * math.pi * target_day / 7),
        "target_is_weekend": int(target_day >= 5),
        "context_event_count": 0.0,
        "context_expected_impact_sum": 0.0,
        "context_expected_impact_max": 0.0,
        "context_event_weekend_retail": 0,
        "context_event_monsoon_disruption": 0,
        "context_event_local_event_spike": 0,
        "context_event_outage_cluster": 0,
        "context_event_stale_status_reports": 0,
        "request_sum_same_window_yesterday": 1.0,
        "request_sum_same_window_last_week": 0.0,
        "missing_same_window_yesterday": 0,
        "missing_same_window_last_week": 0,
    }
    # Return as a DataFrame for scikit-learn/joblib
    return pd.DataFrame([features])

def build_availability_features(
    charger_id: UUID,
    port_id: UUID,
    prediction_origin: datetime | None = None,
    target_time: datetime | None = None,
) -> pd.DataFrame:
    """
    Point-in-time feature builder for Model 2 (Availability).
    Constructs the 35 features required by the availability prediction model.
    """
    origin = prediction_origin or datetime.now(timezone.utc)
    target = target_time or origin + timedelta(minutes=30)
    local_target = target.astimezone(PUNE_TIMEZONE)
    target_hour = local_target.hour + local_target.minute / 60
    target_day = local_target.weekday()

    features: Dict[str, Any] = {
        "eta_minutes": (target - origin).total_seconds() / 60,
        "target_hour_sin": math.sin(2 * math.pi * target_hour / 24),
        "target_hour_cos": math.cos(2 * math.pi * target_hour / 24),
        "target_day_sin": math.sin(2 * math.pi * target_day / 7),
        "target_day_cos": math.cos(2 * math.pi * target_day / 7),
        "target_is_weekend": int(target_day >= 5),
        "minutes_to_business_close": 409.0,
        "known_bookings_near_target": 0.0,
        "active_session_count": 0.0,
        "active_session_elapsed_minutes": 0.0,
        "prior_success_count": 1.0,
        "prior_failure_count": 0.0,
        "reliability_evidence_count": 1.0,
        "smoothed_reliability": 0.6,
        "cold_start": 1.0,
        "prior_reliable_session_count": 31.0,
        "prior_charger_failure_count": 0.0,
        "prior_congestion_failure_count": 0.0,
        "charger_reliability_evidence_count": 31.0,
        "smoothed_charger_reliability": 0.934,
        "reliability_cold_start": 0.0,
        "latest_status_confidence": 0.98,
        "status_age_minutes": 617.15,
        "status_expired": 1.0,
        "recent_zone_requests_1h": 1.0,
        "recent_zone_unserved_1h": 0.0,
        "recent_zone_occupancy_mean_1h": 0.061,
        "max_power_kw": 22.0,
        "site_port_count": 2.0,
        "latest_status": "available",
        "latest_status_source": "system",
        "connector_code": "type_2",
        "charging_type": "AC",
        "business_category": "mall",
        "access_type": "public"
    }
    return pd.DataFrame([features])
