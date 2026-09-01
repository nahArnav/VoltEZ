import json
import math
from collections import Counter, defaultdict
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from geoalchemy2 import Geometry as GeometryType
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_current_user
from app.core.config import settings
from app.core.logging import get_logger
from app.db.session import get_db
from app.repositories.business import business_repo
from app.schemas.enums import BookingStatus, UserRole
from app.services.n8n import n8n_service
from database.models.booking import Booking
from database.models.charger import Charger
from database.models.charger_port import ChargerPort
from database.models.charging_session import ChargingSession
from database.models.user import User

logger = get_logger("ai_copilot")
router = APIRouter(prefix="/ai", tags=["AI & Copilot"])


def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0
    dLat = math.radians(lat2 - lat1)
    dLon = math.radians(lon2 - lon1)
    a = (
        math.sin(dLat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dLon / 2) ** 2
    )
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


# ─────────────────────────────────────────────────────────────────────────────
# 1. AI Charging Advice Schemas & Endpoint
# ─────────────────────────────────────────────────────────────────────────────
class LocationCoords(BaseModel):
    lat: float = Field(default=18.5204, description="Latitude")
    lng: float = Field(default=73.8567, description="Longitude")


class ChargingAdviceRequest(BaseModel):
    battery_percentage: float = Field(default=32.0, ge=0.0, le=100.0)
    current_location: LocationCoords = Field(default_factory=LocationCoords)
    destination: str | None = Field(default=None, description="Trip destination (e.g., 'Mumbai')")
    vehicle_model: str | None = Field(default="Standard 4W EV")
    vehicle_range_km: float | None = Field(default=None)


class ChargerOption(BaseModel):
    id: str | None = None
    name: str
    distance_km: float
    available_ports: int
    total_ports: int
    price_per_kwh: float
    wait_minutes: int
    charging_speed_kw: float
    address: str | None = None


class ChargingAdviceResponse(BaseModel):
    recommendation: str
    recommended_station: ChargerOption | None = None
    all_options: list[ChargerOption] = []
    structured_context: dict[str, Any]
    source: str
    model: str


async def _call_gemini(prompt: str) -> str | None:
    gemini_key = settings.GEMINI_API_KEY.strip()
    if not gemini_key:
        return None

    headers = {
        "x-goog-api-key": gemini_key,
        "Content-Type": "application/json",
    }

    # Try preferred Gemini models in order
    for model_name in [
        "models/gemini-3.6-flash",
        "models/gemini-2.0-flash",
        "models/gemini-flash-latest",
        "models/gemini-pro-latest",
    ]:
        try:
            url = f"https://generativelanguage.googleapis.com/v1beta/{model_name}:generateContent?key={gemini_key}"
            async with httpx.AsyncClient(timeout=8.0) as client:
                resp = await client.post(
                    url,
                    headers=headers,
                    json={
                        "contents": [{"parts": [{"text": prompt}]}],
                        "generationConfig": {"temperature": 0.2, "maxOutputTokens": 500},
                    },
                )
                if resp.status_code == 200:
                    data = resp.json()
                    candidates = data.get("candidates", [])
                    if candidates:
                        content = candidates[0].get("content", {})
                        parts = content.get("parts", [])
                        if parts and "text" in parts[0]:
                            return parts[0]["text"].strip()
                else:
                    logger.debug("Gemini %s responded with HTTP %d: %s", model_name, resp.status_code, resp.text[:150])
        except Exception as exc:
            logger.warning("Gemini API call to %s failed: %s", model_name, exc)
            continue
    return None


@router.post("/charging-advice", response_model=ChargingAdviceResponse)
async def get_ai_charging_advice(
    req: ChargingAdviceRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    AI-powered charging station recommendation based on vehicle SoC, route, and live station availability.
    Strictly prevents hallucinations by providing verified structured station data to Gemini.
    """
    user_lat = req.current_location.lat
    user_lng = req.current_location.lng

    # 1. Fetch real, operational chargers from the database. Port
    # availability is derived from active ports and bookings that overlap the
    # current instant; it is never inferred from station count or demo data.
    chargers_query = await db.execute(
        select(
            Charger.id,
            Charger.name,
            Charger.address_text,
            func.ST_Y(Charger.location.cast(GeometryType)).label("latitude"),
            func.ST_X(Charger.location.cast(GeometryType)).label("longitude"),
            Charger.price_per_kwh,
            Charger.status,
            Charger.power_kw,
        )
        .where(Charger.status == "available")
    )
    rows = chargers_query.all()

    charger_ids = [row.id for row in rows]
    ports = []
    if charger_ids:
        ports = list(
            (
                await db.execute(
                    select(ChargerPort).where(
                        ChargerPort.charger_id.in_(charger_ids)
                    )
                )
            )
            .scalars()
            .all()
        )

    ports_by_charger: dict[UUID, list[ChargerPort]] = defaultdict(list)
    for port in ports:
        ports_by_charger[port.charger_id].append(port)

    now = datetime.now(UTC)
    active_booking_statuses = {
        BookingStatus.CONFIRMED.value,
        BookingStatus.CHECKED_IN.value,
        BookingStatus.CHARGING.value,
        BookingStatus.IN_PROGRESS.value,
    }
    occupied_until: dict[UUID, datetime] = {}
    active_port_ids = [port.id for port in ports if port.is_active]
    if active_port_ids:
        booking_rows = (
            await db.execute(
                select(Booking.charger_port_id, Booking.end_at).where(
                    Booking.charger_port_id.in_(active_port_ids),
                    Booking.status.in_(active_booking_statuses),
                    Booking.start_at <= now,
                    Booking.end_at > now,
                )
            )
        ).all()
        for port_id, end_at in booking_rows:
            previous = occupied_until.get(port_id)
            if previous is None or end_at < previous:
                occupied_until[port_id] = end_at

    options: list[ChargerOption] = []
    for r in rows:
        if r.latitude is None or r.longitude is None:
            continue
        charger_ports = ports_by_charger.get(r.id, [])
        active_ports = [port for port in charger_ports if port.is_active]
        if not active_ports:
            continue

        c_lat = float(r.latitude)
        c_lng = float(r.longitude)
        dist = round(_haversine(user_lat, user_lng, c_lat, c_lng), 2)
        total_p = len(charger_ports)
        free_ports = [port for port in active_ports if port.id not in occupied_until]
        avail_p = len(free_ports)
        if avail_p > 0:
            wait_m = 0
        else:
            next_end = min(
                (
                    occupied_until[port.id]
                    for port in active_ports
                    if port.id in occupied_until
                ),
                default=None,
            )
            wait_m = (
                max(1, math.ceil((next_end - now).total_seconds() / 60))
                if next_end is not None
                else 0
            )
        power = max(float(port.max_power_kw) for port in active_ports)
        tariff = float(r.price_per_kwh)

        options.append(
            ChargerOption(
                id=str(r.id),
                name=r.name,
                distance_km=dist,
                available_ports=avail_p,
                total_ports=total_p,
                price_per_kwh=tariff,
                wait_minutes=wait_m,
                charging_speed_kw=power,
                address=r.address_text,
            )
        )

    estimated_range = (
        round((req.battery_percentage / 100.0) * req.vehicle_range_km, 1)
        if req.vehicle_range_km is not None
        else None
    )

    if not options:
        structured_context = {
            "vehicle": {
                "model": req.vehicle_model,
                "battery_percentage": req.battery_percentage,
                "estimated_range_km": estimated_range,
                "destination": req.destination,
            },
            "chargers": [],
        }
        return ChargingAdviceResponse(
            recommendation=(
                "No live, bookable chargers are currently available in the "
                "database. Refresh discovery or widen the search area."
            ),
            recommended_station=None,
            all_options=[],
            structured_context=structured_context,
            source="VoltEZ live database",
            model="deterministic-empty-state",
        )

    # Sort options by a multi-factor score (distance, availability, speed, price)
    options.sort(
        key=lambda o: (
            0 if o.available_ports > 0 else 1,
            o.wait_minutes,
            o.distance_km,
            -o.charging_speed_kw,
            o.price_per_kwh,
        )
    )
    best_candidate = options[0]

    # 2. Build structured context payload matching PDF specification
    structured_context = {
        "vehicle": {
            "model": req.vehicle_model,
            "battery_percentage": req.battery_percentage,
            "estimated_range_km": estimated_range,
            "destination": req.destination,
        },
        "chargers": [
            {
                "name": opt.name,
                "distance_km": opt.distance_km,
                "available_ports": opt.available_ports,
                "total_ports": opt.total_ports,
                "price_per_kwh": opt.price_per_kwh,
                "wait_minutes": opt.wait_minutes,
                "charging_speed_kw": opt.charging_speed_kw,
            }
            for opt in options[:5]
        ],
    }

    # 3. Prompt Gemini
    prompt = (
        "You are the VoltEZ EV charging assistant.\n"
        "Use ONLY the provided charger data.\n"
        "Do not invent availability, prices, distances, wait times, or charger specifications.\n\n"
        "Recommend the best charger based on:\n"
        "1. Distance\n"
        "2. Availability\n"
        "3. Waiting time\n"
        "4. Charging speed\n"
        "5. Price\n\n"
        "Explain the recommendation in simple, concise language (2-3 sentences max).\n\n"
        f"Vehicle Context: Battery {req.battery_percentage}%, "
        f"Est. Range {estimated_range if estimated_range is not None else 'not provided'}km"
        f"{f', heading to {req.destination}' if req.destination else ''}.\n\n"
        f"Charger data:\n{json.dumps(structured_context['chargers'], indent=2)}"
    )

    ai_text = await _call_gemini(prompt)
    if ai_text:
        return ChargingAdviceResponse(
            recommendation=ai_text,
            recommended_station=best_candidate,
            all_options=options,
            structured_context=structured_context,
            source="Google Gemini",
            model="gemini-flash",
        )

    # Deterministic, data-backed fallback. Every value below comes from the
    # same live option used for ranking; no Gemini output is simulated.
    fallback_text = (
        f"I recommend {best_candidate.name} located {best_candidate.distance_km} km away. "
        f"It has {best_candidate.available_ports} free active port(s), a "
        f"{best_candidate.charging_speed_kw:.0f} kW maximum port and a live "
        f"₹{best_candidate.price_per_kwh}/kWh base tariff."
    )

    return ChargingAdviceResponse(
        recommendation=fallback_text,
        recommended_station=best_candidate,
        all_options=options,
        structured_context=structured_context,
        source="VoltEZ AI Optimizer",
        model="heuristic-engine",
    )


# ─────────────────────────────────────────────────────────────────────────────
# 2. AI Business Dashboard Insights Schemas & Endpoint
# ─────────────────────────────────────────────────────────────────────────────
class BusinessInsightRequest(BaseModel):
    business_id: UUID
    question: str = "Why did charger utilization change this week?"
    timeframe_days: int = Field(default=7, ge=1, le=90)


class BusinessInsightResponse(BaseModel):
    question: str
    insight: str
    metrics: dict[str, Any]
    source: str
    model: str


@router.post("/business-insights", response_model=BusinessInsightResponse)
async def get_business_insights(
    req: BusinessInsightRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    AI-powered diagnostic assistant for charging station operators.
    Provides data-backed explanations for revenue shifts, peak hours, and downtime.
    """
    business = await business_repo.get(db, id=req.business_id)
    if business is None or (
        current_user.role != UserRole.ADMIN and business.owner_id != current_user.id
    ):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business not found")

    chargers = list(
        (
            await db.execute(
                select(Charger).where(Charger.business_id == req.business_id)
            )
        )
        .scalars()
        .all()
    )
    charger_ids = [charger.id for charger in chargers]
    ports = []
    if charger_ids:
        ports = list(
            (
                await db.execute(
                    select(ChargerPort).where(ChargerPort.charger_id.in_(charger_ids))
                )
            )
            .scalars()
            .all()
        )

    since = datetime.now(UTC) - timedelta(days=req.timeframe_days)
    port_ids = [port.id for port in ports]
    sessions = []
    if port_ids:
        sessions = list(
            (
                await db.execute(
                    select(ChargingSession).where(
                        ChargingSession.charger_port_id.in_(port_ids),
                        ChargingSession.reserved_at >= since,
                    )
                )
            )
            .scalars()
            .all()
        )

    completed = [session for session in sessions if str(session.status).lower() == "completed"]
    failed = [
        session
        for session in sessions
        if str(session.status).lower() in {"failed", "error"}
    ]
    charging_minutes = sum(
        max(0.0, (session.ended_at - session.started_at).total_seconds() / 60)
        for session in sessions
        if session.started_at is not None and session.ended_at is not None
    )
    capacity_minutes = len([port for port in ports if port.is_active]) * req.timeframe_days * 1440
    utilization = (
        min(100.0, charging_minutes / capacity_minutes * 100)
        if capacity_minutes > 0
        else 0.0
    )
    start_hours = Counter(
        session.started_at.hour for session in sessions if session.started_at is not None
    )
    peak_hour = start_hours.most_common(1)[0][0] if start_hours else None

    metrics = {
        "timeframe_days": req.timeframe_days,
        "chargers": len(chargers),
        "active_chargers": sum(
            1
            for charger in chargers
            if str(charger.status).lower() == "available"
            and any(port.is_active for port in ports if port.charger_id == charger.id)
        ),
        "total_sessions": len(sessions),
        "completed_sessions": len(completed),
        "failed_sessions": len(failed),
        "revenue_inr": round(sum(float(session.amount or 0) for session in completed), 2),
        "charging_minutes": round(charging_minutes, 1),
        "utilization_rate_pct": round(utilization, 2),
        "peak_start_hour": f"{peak_hour:02d}:00" if peak_hour is not None else None,
    }

    prompt = (
        "You are the VoltEZ Business AI Analyst for EV charging station operators in India.\n"
        "Explain the business question concisely (2-4 sentences) using ONLY the operational metrics below.\n"
        "Identify root causes (e.g. downtime, failed sessions, peak bottlenecks) and suggest 1 actionable remedy.\n\n"
        f"Question: {req.question}\n\n"
        f"Metrics:\n{json.dumps(metrics, indent=2)}"
    )

    ai_text = await _call_gemini(prompt)
    if ai_text:
        return BusinessInsightResponse(
            question=req.question,
            insight=ai_text,
            metrics=metrics,
            source="Google Gemini",
            model="gemini-flash",
        )

    if not sessions:
        fallback_text = (
            f"No charging sessions were recorded in the last {req.timeframe_days} "
            "days, so VoltEZ cannot infer a utilization trend yet."
        )
    else:
        fallback_text = (
            f"In the last {req.timeframe_days} days, {len(completed)} of "
            f"{len(sessions)} sessions completed and generated "
            f"₹{metrics['revenue_inr']:.2f}. Measured port utilization was "
            f"{metrics['utilization_rate_pct']:.1f}% based on recorded charging time."
        )

    return BusinessInsightResponse(
        question=req.question,
        insight=fallback_text,
        metrics=metrics,
        source="VoltEZ Analytics Engine",
        model="heuristic-engine",
    )


# ─────────────────────────────────────────────────────────────────────────────
# 3. Charger Incident Automation & Analysis Schemas & Endpoint
# ─────────────────────────────────────────────────────────────────────────────
class IncidentAlertRequest(BaseModel):
    station_id: str = "ST-102"
    station_name: str = "Hinjewadi Station"
    status: str = "offline"
    offline_duration_minutes: int = 17
    available_ports: int = 0
    total_ports: int = 6
    notes: str | None = None


class IncidentAlertResponse(BaseModel):
    incident_id: str
    station_id: str
    severity: str
    gemini_summary: str
    n8n_delivery: dict[str, Any]


@router.post("/incident-alert", response_model=IncidentAlertResponse)
async def report_charger_incident(req: IncidentAlertRequest):
    """
    Handle charger outage, trigger AI analysis via Gemini, and dispatch to n8n webhook.
    """
    import uuid

    incident_id = f"inc_{uuid.uuid4().hex[:8]}"

    # Assess severity
    severity = "CRITICAL" if req.available_ports == 0 and req.total_ports >= 4 else "HIGH" if req.status == "offline" else "MEDIUM"

    # Generate Gemini Incident Summary
    prompt = (
        "You are the VoltEZ Incident Response AI.\n"
        "Generate a 1-2 sentence operational alert for station operators and technicians based on this outage:\n"
        f"Station: {req.station_name} ({req.station_id})\n"
        f"Status: {req.status}\n"
        f"Offline Duration: {req.offline_duration_minutes} minutes\n"
        f"Available Ports: {req.available_ports}/{req.total_ports}\n"
        f"Severity: {severity}\n"
    )

    ai_text = await _call_gemini(prompt)
    if not ai_text:
        ai_text = (
            f"Station {req.station_name} ({req.station_id}) is experiencing a {severity.lower()} service interruption. "
            f"All {req.total_ports} ports have been offline for {req.offline_duration_minutes} minutes, affecting nearby EV drivers."
        )

    # Dispatch to n8n
    n8n_result = await n8n_service.send_incident_alert(
        station_id=req.station_id,
        station_name=req.station_name,
        status=req.status,
        offline_duration_minutes=req.offline_duration_minutes,
        available_ports=req.available_ports,
        total_ports=req.total_ports,
        notes=f"AI Summary: {ai_text}",
    )

    return IncidentAlertResponse(
        incident_id=incident_id,
        station_id=req.station_id,
        severity=severity,
        gemini_summary=ai_text,
        n8n_delivery=n8n_result,
    )
