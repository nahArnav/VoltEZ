"""Point-in-time feature builders used by the live ML adapters.

The training jobs and serving code must use the same feature names and
semantics. These builders intentionally use only rows that existed before the
prediction timestamp. Missing history is represented by a zero plus the
corresponding missing flag; it is never replaced with a Pune fixture value.
"""

import math
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID
from zoneinfo import ZoneInfo

from geoalchemy2 import Geometry as GeometryType
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from database.models.analytics_demand_bucket import DemandBucket
from database.models.booking import Booking
from database.models.business import Business
from database.models.business_hours import BusinessHours
from database.models.charger import Charger
from database.models.charger_port import ChargerPort
from database.models.charger_search_event import ChargerSearchEvent
from database.models.charger_status_event import ChargerStatusEvent
from database.models.charging_session import ChargingSession
from database.models.connector import ConnectorType
from database.models.context_event import ContextEvent
from database.models.zone import Zone

PUNE_TIMEZONE = ZoneInfo("Asia/Kolkata")
ACTIVE_BOOKING_STATUSES = {"pending", "held", "confirmed", "checked_in", "charging"}


def _utc(value: datetime) -> datetime:
    return value if value.tzinfo is not None else value.replace(tzinfo=UTC)


def _periodic(local_target: datetime) -> dict[str, float | int]:
    hour = local_target.hour + local_target.minute / 60
    day = local_target.weekday()
    return {
        "target_hour_sin": math.sin(2 * math.pi * hour / 24),
        "target_hour_cos": math.cos(2 * math.pi * hour / 24),
        "target_day_sin": math.sin(2 * math.pi * day / 7),
        "target_day_cos": math.cos(2 * math.pi * day / 7),
        "target_is_weekend": int(day >= 5),
    }


def _bucket_value(rows: list[DemandBucket], anchor: datetime, minutes_ago: int) -> float | None:
    """Return the nearest completed analytics bucket at or before the anchor."""
    wanted = anchor - timedelta(minutes=minutes_ago)
    prior = [_utc(row.time_bucket) for row in rows if _utc(row.time_bucket) <= wanted]
    if not prior:
        return None
    nearest = max(prior)
    row = next(row for row in rows if _utc(row.time_bucket) == nearest)
    return max(float(row.demand_score), 0.0)


def _zone_flags(zone_type: str | None) -> dict[str, int]:
    value = (zone_type or "").strip().lower()
    return {
        f"zone_type_{name}": int(value == name)
        for name in ("commercial", "industrial", "mixed", "office", "residential", "retail", "transit")
    }


async def build_demand_features(
    db: AsyncSession,
    charger_id: UUID,
    prediction_origin: datetime | None = None,
) -> Any:
    """Build the 52 Model 1 features from live operational history."""
    origin = _utc(prediction_origin or datetime.now(UTC))
    target = origin + timedelta(minutes=15)
    local_target = target.astimezone(PUNE_TIMEZONE)

    charger = await db.get(Charger, charger_id)
    if charger is None:
        raise ValueError("Charger not found")
    business = await db.get(Business, charger.business_id)
    zone = await db.get(Zone, business.zone_id) if business is not None else None
    zone_id = zone.id if zone is not None else None

    port_rows = await db.execute(
        select(ChargerPort.id, ChargerPort.is_active).where(ChargerPort.charger_id == charger_id)
    )
    port_records = list(port_rows.all())
    port_ids = [record[0] for record in port_records]
    listed_ports = len(port_ids)

    bucket_rows: list[DemandBucket] = []
    if zone_id is not None:
        result = await db.execute(
            select(DemandBucket)
            .where(DemandBucket.zone_id == zone_id, DemandBucket.time_bucket <= origin)
            .order_by(DemandBucket.time_bucket.desc())
            .limit(9000)
        )
        bucket_rows = list(result.scalars().all())

    bucket_count = len(bucket_rows)
    lag_1 = _bucket_value(bucket_rows, origin, 15) or 0.0
    lag_4 = [_bucket_value(bucket_rows, origin, 15 * i) for i in range(1, 5)]
    lag_24 = [_bucket_value(bucket_rows, origin, 15 * i) for i in range(1, 25)]
    prior_values = [value for value in lag_24 if value is not None]
    mean_prior = sum(prior_values) / len(prior_values) if prior_values else 0.0
    std_prior = (
        math.sqrt(sum((value - mean_prior) ** 2 for value in prior_values) / len(prior_values))
        if prior_values
        else 0.0
    )
    ewm = 0.0
    for value in reversed(prior_values):
        ewm = 0.35 * value + 0.65 * ewm

    async def search_count(start: datetime, end: datetime) -> tuple[int, int]:
        if zone_id is None:
            return 0, 0
        result = await db.execute(
            select(ChargerSearchEvent).where(
                ChargerSearchEvent.zone_id == zone_id,
                ChargerSearchEvent.created_at >= start,
                ChargerSearchEvent.created_at < end,
            )
        )
        rows = list(result.scalars().all())
        return len(rows), sum(1 for row in rows if row.chargers_found == 0)

    current_searches, current_unserved = await search_count(origin - timedelta(minutes=15), origin)
    hour_searches, hour_unserved = await search_count(origin - timedelta(hours=1), origin)
    booking_result = await db.execute(
        select(Booking).where(
            Booking.charger_port_id.in_(port_ids or [UUID(int=0)]),
            Booking.start_at < origin,
            Booking.end_at > origin - timedelta(minutes=15),
            Booking.status.in_(ACTIVE_BOOKING_STATUSES),
        )
    )
    active_bookings = list(booking_result.scalars().all())
    session_result = await db.execute(
        select(ChargingSession).where(
            ChargingSession.charger_port_id.in_(port_ids or [UUID(int=0)]),
            ChargingSession.started_at <= origin,
            (ChargingSession.ended_at.is_(None) | (ChargingSession.ended_at > origin)),
        )
    )
    active_sessions = list(session_result.scalars().all())
    available_ports = (
        sum(1 for _, is_active in port_records if is_active)
        if getattr(charger, "status", "") == "available"
        else 0
    )

    context_count = context_sum = context_max = 0.0
    event_flags = {
        "context_event_weekend_retail": 0,
        "context_event_monsoon_disruption": 0,
        "context_event_local_event_spike": 0,
        "context_event_outage_cluster": 0,
        "context_event_stale_status_reports": 0,
    }
    context_result = await db.execute(
        select(ContextEvent).where(
            ContextEvent.timestamp <= target,
            ContextEvent.timestamp >= target - timedelta(hours=24),
        )
    )
    for event in context_result.scalars().all():
        context_count += 1
        impact = float((event.data or {}).get("expected_impact", 0.0) or 0.0)
        context_sum += max(impact, 0.0)
        context_max = max(context_max, max(impact, 0.0))
        event_type = event.event_type.lower()
        if "weekend" in event_type or "retail" in event_type:
            event_flags["context_event_weekend_retail"] = 1
        if "monsoon" in event_type or "rain" in event_type:
            event_flags["context_event_monsoon_disruption"] = 1
        if "event" in event_type:
            event_flags["context_event_local_event_spike"] = 1
        if "outage" in event_type:
            event_flags["context_event_outage_cluster"] = 1
        if "stale" in event_type:
            event_flags["context_event_stale_status_reports"] = 1

    centroid_lat = centroid_lon = 0.0
    if zone is not None and zone.centroid is not None:
        centroid_result = await db.execute(
            select(
                func.ST_Y(Zone.centroid.cast(GeometryType)),
                func.ST_X(Zone.centroid.cast(GeometryType)),
            ).where(Zone.id == zone.id)
        )
        centroid = centroid_result.one_or_none()
        if centroid is not None:
            centroid_lat = float(centroid[0] or 0.0)
            centroid_lon = float(centroid[1] or 0.0)

    def same_window(days: int) -> float | None:
        return _bucket_value(bucket_rows, origin - timedelta(days=days), 0)

    yesterday = same_window(1)
    last_week = same_window(7)
    features: dict[str, Any] = {
        "request_lag_1": lag_1,
        "search_lag_1": float(current_searches),
        "unserved_lag_1": float(current_unserved),
        "booking_lag_1": float(len(active_bookings)),
        "session_lag_1": float(len(active_sessions)),
        "listed_ports_lag_1": float(listed_ports),
        "available_ports_lag_1": float(available_ports),
        "occupancy_lag_1": min(len(active_bookings) / listed_ports, 1.0) if listed_ports else 0.0,
        "request_lag_same_time_yesterday": yesterday or 0.0,
        "request_lag_same_time_last_week": last_week or 0.0,
        "missing_lag_yesterday": int(yesterday is None),
        "missing_lag_last_week": int(last_week is None),
        "request_sum_prior_1_buckets": sum(value for value in lag_4[:1] if value is not None),
        "request_sum_prior_2_buckets": sum(value for value in lag_4[:2] if value is not None),
        "request_sum_prior_4_buckets": sum(value for value in lag_4 if value is not None),
        "request_sum_prior_24_buckets": sum(prior_values),
        "request_mean_prior_window": mean_prior,
        "request_std_prior_window": std_prior,
        "request_ewm_prior": ewm,
        "no_candidate_rate_prior_hour": hour_unserved / hour_searches if hour_searches else 0.0,
        "neighbor_request_lag_1": 0.0,
        "history_bucket_count": float(bucket_count),
        "centroid_latitude": centroid_lat,
        "centroid_longitude": centroid_lon,
        **_zone_flags(getattr(zone, "zone_type", None)),
        "request_lag_target_time_yesterday": yesterday or 0.0,
        "request_lag_target_time_last_week": last_week or 0.0,
        "missing_target_lag_yesterday": int(yesterday is None),
        "missing_target_lag_last_week": int(last_week is None),
        **_periodic(local_target),
        "context_event_count": context_count,
        "context_expected_impact_sum": context_sum,
        "context_expected_impact_max": context_max,
        **event_flags,
        "request_sum_same_window_yesterday": yesterday or 0.0,
        "request_sum_same_window_last_week": last_week or 0.0,
        "missing_same_window_yesterday": int(yesterday is None),
        "missing_same_window_last_week": int(last_week is None),
    }

    import pandas as pd

    return pd.DataFrame([features])


def _normalise_connector(code: str | None) -> str:
    value = (code or "").strip().lower().replace("-", "_").replace(" ", "_")
    return {
        "type2": "type_2",
        "type_2": "type_2",
        "ccs": "ccs2",
        "ccs2": "ccs2",
        "chademo": "chademo",
        "bharat_ac": "bharat_ac_001",
        "bharat_ac_001": "bharat_ac_001",
        "bharat_dc": "bharat_dc_001",
        "bharat_dc_001": "bharat_dc_001",
    }.get(value, "type_2")


async def build_availability_features(
    db: AsyncSession,
    charger_id: UUID,
    port_id: UUID,
    prediction_origin: datetime | None = None,
    target_time: datetime | None = None,
) -> Any:
    """Build Model 2 features from the selected port's live state/history."""
    origin = _utc(prediction_origin or datetime.now(UTC))
    target = _utc(target_time or origin + timedelta(minutes=30))
    local_target = target.astimezone(PUNE_TIMEZONE)
    charger = await db.get(Charger, charger_id)
    port = await db.get(ChargerPort, port_id)
    if charger is None or port is None or port.charger_id != charger_id:
        raise ValueError("Charger or port not found")
    business = await db.get(Business, charger.business_id)
    connector = await db.get(ConnectorType, port.connector_type_id)

    window_end = target + timedelta(minutes=60)
    bookings_result = await db.execute(
        select(Booking).where(
            Booking.charger_port_id == port_id,
            Booking.start_at < window_end,
            Booking.end_at > target,
            Booking.status.in_(ACTIVE_BOOKING_STATUSES),
        )
    )
    bookings = list(bookings_result.scalars().all())
    sessions_result = await db.execute(
        select(ChargingSession).where(
            ChargingSession.charger_port_id == port_id,
            ChargingSession.started_at <= target,
            (ChargingSession.ended_at.is_(None) | (ChargingSession.ended_at > target)),
        )
    )
    sessions = list(sessions_result.scalars().all())
    elapsed = [
        max(0.0, (target - _utc(session.started_at)).total_seconds() / 60)
        for session in sessions
        if session.started_at is not None
    ]

    status_result = await db.execute(
        select(ChargerStatusEvent)
        .where(
            ChargerStatusEvent.charger_id == charger_id,
            (ChargerStatusEvent.port_id == port_id) | ChargerStatusEvent.port_id.is_(None),
            ChargerStatusEvent.observed_at <= origin,
        )
        .order_by(ChargerStatusEvent.observed_at.desc())
        .limit(1)
    )
    latest_event = status_result.scalar_one_or_none()
    latest_status_raw = (latest_event.status if latest_event else getattr(charger, "status", "unknown")).lower()
    latest_status = {
        "available": "available",
        "active": "available",
        "occupied": "occupied",
        "busy": "occupied",
        "maintenance": "faulted",
        "offline": "faulted",
        "unavailable": "faulted",
    }.get(latest_status_raw, "unknown")
    latest_source_raw = (latest_event.source if latest_event else "system").lower()
    latest_source = {
        "driver_report": "driver_report",
        "driver_check_in": "driver_check_in",
        "driver_check_out": "driver_check_out",
        "owner": "owner",
        "system": "system",
    }.get(latest_source_raw, "system")
    status_age = (
        max(0.0, (origin - _utc(latest_event.observed_at)).total_seconds() / 60)
        if latest_event
        else 0.0
    )
    status_confidence = float(latest_event.confidence) if latest_event else 0.5

    events_result = await db.execute(
        select(ChargerStatusEvent).where(
            ChargerStatusEvent.charger_id == charger_id,
            ChargerStatusEvent.observed_at <= origin,
        )
    )
    status_events = list(events_result.scalars().all())
    failures = sum(1 for event in status_events if event.status.lower() in {"offline", "faulted", "maintenance"})
    successes = max(0, len(status_events) - failures)
    reliability_evidence = len(status_events)

    session_history_result = await db.execute(
        select(ChargingSession).where(
            ChargingSession.charger_port_id == port_id,
            ChargingSession.ended_at.is_not(None),
            ChargingSession.ended_at <= origin,
        )
    )
    session_history = list(session_history_result.scalars().all())
    port_failures = sum(1 for session in session_history if session.status == "failed")
    port_successes = max(0, len(session_history) - port_failures)
    smoothed_port = (port_successes + 2) / (port_successes + port_failures + 4)
    smoothed_charger = (successes + 2) / (successes + failures + 4)

    site_ports_result = await db.execute(select(ChargerPort.id).where(ChargerPort.charger_id == charger_id))
    site_port_count = len(list(site_ports_result.scalars().all()))

    recent_requests = recent_unserved = 0
    if business is not None:
        search_result = await db.execute(
            select(ChargerSearchEvent).where(
                ChargerSearchEvent.zone_id == business.zone_id,
                ChargerSearchEvent.created_at >= origin - timedelta(hours=1),
                ChargerSearchEvent.created_at <= origin,
            )
        )
        search_rows = list(search_result.scalars().all())
        recent_requests = len(search_rows)
        recent_unserved = sum(1 for row in search_rows if row.chargers_found == 0)

    close_minutes = 0.0
    if business is not None:
        hours_result = await db.execute(
            select(BusinessHours).where(
                BusinessHours.business_id == business.id,
                BusinessHours.day_of_week == local_target.weekday(),
                BusinessHours.is_closed.is_(False),
            ).limit(1)
        )
        hours = hours_result.scalar_one_or_none()
        if hours is not None:
            close = datetime.combine(local_target.date(), hours.close_local_time, tzinfo=PUNE_TIMEZONE)
            close_minutes = max(0.0, (close - local_target).total_seconds() / 60)

    category = (getattr(business, "category", "office") or "office").lower() if business else "office"
    features: dict[str, Any] = {
        "eta_minutes": max(0.0, (target - origin).total_seconds() / 60),
        **_periodic(local_target),
        "minutes_to_business_close": close_minutes,
        "known_bookings_near_target": float(len(bookings)),
        "active_session_count": float(len(sessions)),
        "active_session_elapsed_minutes": max(elapsed, default=0.0),
        "prior_success_count": float(port_successes),
        "prior_failure_count": float(port_failures),
        "reliability_evidence_count": float(reliability_evidence),
        "smoothed_reliability": float(smoothed_port),
        "cold_start": float(int(not session_history)),
        "prior_reliable_session_count": float(port_successes),
        "prior_charger_failure_count": float(failures),
        "prior_congestion_failure_count": 0.0,
        "charger_reliability_evidence_count": float(reliability_evidence),
        "smoothed_charger_reliability": float(smoothed_charger),
        "reliability_cold_start": float(int(not status_events)),
        "latest_status_confidence": min(max(status_confidence, 0.0), 1.0),
        "status_age_minutes": status_age,
        "status_expired": float(int(status_age > 60)),
        "recent_zone_requests_1h": float(recent_requests),
        "recent_zone_unserved_1h": float(recent_unserved),
        "recent_zone_occupancy_mean_1h": min(len(bookings) / site_port_count, 1.0) if site_port_count else 0.0,
        "max_power_kw": float(port.max_power_kw),
        "site_port_count": float(site_port_count),
        "latest_status": latest_status,
        "latest_status_source": latest_source,
        "connector_code": _normalise_connector(getattr(connector, "code", None)),
        "charging_type": "DC" if (getattr(connector, "current_type", "AC") or "AC").upper() == "DC" else "AC",
        "business_category": category if category in {"cafe", "fuel_station", "hotel", "mall", "office", "residential"} else "office",
        "access_type": getattr(charger, "access_type", "public") or "public",
    }

    import pandas as pd

    return pd.DataFrame([features])
