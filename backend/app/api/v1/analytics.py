from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_current_user, get_db
from app.ml.adapters import ml_adapter
from app.repositories.business import business_repo
from app.repositories.charger import charger_repo
from app.schemas.enums import UserRole
from database.models.booking import Booking
from database.models.charger import Charger
from database.models.charger_port import ChargerPort
from database.models.charging_session import ChargingSession
from database.models.review import Review
from database.models.user import User

router = APIRouter(prefix="/analytics", tags=["Analytics & Intelligence"])


class RecommendationResponse(BaseModel):
    charger_id: UUID
    recommended_action: str
    reason_code: str
    expected_demand: float
    suggested_discount_pct: int
    confidence: float


class DashboardResponse(BaseModel):
    chargers: int
    active_chargers: int
    sessions: int
    bookings: int
    confirmed_bookings: int
    total_earnings: float
    active_minutes: float
    average_rating: float | None = None
    reviews: list[dict]


from fastapi import Request


@router.get(
    "/businesses/{business_id}/recommendations", response_model=list[RecommendationResponse]
)
async def get_business_recommendations(
    business_id: UUID,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Derived Business Intelligence:
    Queries ML demand forecasting to recommend dynamic availability/pricing to owners.
    """
    if current_user.role not in [UserRole.OWNER, UserRole.ADMIN]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
    business = await business_repo.get(db, id=business_id)
    if business is None or (
        current_user.role != UserRole.ADMIN and business.owner_id != current_user.id
    ):
        raise HTTPException(status_code=404, detail="Business not found")

    # Get all chargers for this business
    chargers = await charger_repo.get_by_business(db, business_id=business_id)
    if not chargers:
        return []

    recommendations = []

    demand_model = getattr(request.app.state, "demand_model", None)

    for charger in chargers:
        # Call Model A (Demand Forecast)
        forecast = await ml_adapter.predict_demand(db, charger_id=charger.id, model=demand_model)
        expected = forecast["expected_demand"]
        confidence = forecast["confidence"]

        # Derive intelligence logic based on Model 1 target distribution (mean ~0.9, p99 = 5.0)
        if expected < 0.5:
            # Low demand -> suggest discount
            recommendations.append(
                RecommendationResponse(
                    charger_id=charger.id,
                    recommended_action="Create Availability Window",
                    reason_code="BUSINESS_OFF_PEAK",
                    expected_demand=expected,
                    suggested_discount_pct=20,
                    confidence=confidence,
                )
            )
        elif expected > 2.0:
            # High demand -> surge pricing or hold slots
            recommendations.append(
                RecommendationResponse(
                    charger_id=charger.id,
                    recommended_action="Enable Peak Pricing",
                    reason_code="HIGH_DEMAND_LOW_SUPPLY",
                    expected_demand=expected,
                    suggested_discount_pct=0,
                    confidence=confidence,
                )
            )

    # MLAdapter records each forecast for auditability and drift monitoring.
    # The repository flushes those rows but does not commit them; persist the
    # batch once after all chargers have been evaluated so a read-only
    # dashboard request does not silently roll the audit trail back.
    await db.commit()
    return recommendations


@router.get("/businesses/{business_id}/dashboard", response_model=DashboardResponse)
async def get_business_dashboard(
    business_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return live owner metrics computed from bookings, sessions and reviews."""
    if current_user.role not in [UserRole.OWNER, UserRole.ADMIN]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
    business = await business_repo.get(db, id=business_id)
    if business is None or (
        current_user.role != UserRole.ADMIN and business.owner_id != current_user.id
    ):
        raise HTTPException(status_code=404, detail="Business not found")

    chargers_result = await db.execute(
        select(Charger).where(Charger.business_id == business_id)
    )
    chargers = list(chargers_result.scalars().all())
    charger_ids = [charger.id for charger in chargers]
    # A station is active only when the station itself is available and at
    # least one connector is active. Compare case-insensitively because older
    # rows/imports used uppercase status values.
    active_chargers = sum(
        1
        for charger in chargers
        if str(charger.status).lower() == "available"
        and any(port.is_active for port in charger.ports)
    )
    if not charger_ids:
        return DashboardResponse(
            chargers=0,
            active_chargers=0,
            sessions=0,
            bookings=0,
            confirmed_bookings=0,
            total_earnings=0.0,
            active_minutes=0.0,
            average_rating=None,
            reviews=[],
        )

    port_ids_result = await db.execute(
        select(ChargerPort.id).where(ChargerPort.charger_id.in_(charger_ids))
    )
    port_ids = list(port_ids_result.scalars().all())
    if not port_ids:
        return DashboardResponse(
            chargers=len(chargers), active_chargers=active_chargers, sessions=0,
            bookings=0, confirmed_bookings=0, total_earnings=0.0,
            active_minutes=0.0, average_rating=None, reviews=[]
        )

    bookings_result = await db.execute(
        select(Booking).where(Booking.charger_port_id.in_(port_ids))
    )
    bookings = list(bookings_result.scalars().all())
    sessions_result = await db.execute(
        select(ChargingSession).where(ChargingSession.charger_port_id.in_(port_ids))
    )
    sessions = list(sessions_result.scalars().all())
    # Revenue is based on completed charging telemetry, not reservation
    # estimates. A confirmed booking may still be cancelled, no-show, or
    # awaiting cash settlement, and Booking has no `total_price` column.
    # ChargingSession.amount is the server-calculated delivered-energy charge.
    total_earnings = sum(
        float(session.amount or 0)
        for session in sessions
        if str(session.status).lower() == "completed"
    )
    active_minutes = sum(
        max(0.0, (session.ended_at - session.started_at).total_seconds() / 60.0)
        for session in sessions
        if session.started_at is not None and session.ended_at is not None
    )
    session_ids = [session.id for session in sessions]
    reviews = []
    if session_ids:
        reviews_result = await db.execute(
            select(Review).where(Review.session_id.in_(session_ids)).order_by(Review.created_at.desc())
        )
        reviews = [
            {"id": str(review.id), "session_id": str(review.session_id), "rating": review.rating,
             "comment": review.comment, "created_at": review.created_at.isoformat()}
            for review in reviews_result.scalars().all()
        ]
    average_rating = (
        sum(item["rating"] for item in reviews) / len(reviews) if reviews else None
    )
    return DashboardResponse(
        chargers=len(chargers),
        active_chargers=active_chargers,
        sessions=len(sessions),
        bookings=len(bookings),
        confirmed_bookings=sum(1 for booking in bookings if str(booking.status).upper() in ("CONFIRMED", "CHECKED_IN", "COMPLETED")),
        total_earnings=round(total_earnings, 2),
        active_minutes=round(active_minutes, 1),

        average_rating=round(average_rating, 2) if average_rating is not None else None,
        reviews=reviews,
    )
