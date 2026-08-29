from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_current_user_id
from app.db.session import get_db
from app.repositories.session import review_repo, session_repo
from app.schemas.charging_session import ChargingSessionResponse
from app.schemas.review import ReviewCreate, ReviewResponse
from app.services.session import session_service
from database.models.charging_session import ChargingSession
from database.models.charger import Charger
from database.models.charger_port import ChargerPort
from database.models.connector import ConnectorType

router = APIRouter(prefix="/sessions", tags=["Sessions"])


async def _with_charger_context(db: AsyncSession, session: ChargingSession) -> dict:
    """Serialize a session with real charger/port data for driver history."""
    result = await db.execute(
        select(
            Charger.name,
            Charger.address_text,
            Charger.price_per_kwh,
            ChargerPort.max_power_kw,
            ConnectorType.display_name,
        )
        .select_from(ChargingSession)
        .join(ChargerPort, ChargingSession.charger_port_id == ChargerPort.id)
        .join(Charger, ChargerPort.charger_id == Charger.id)
        .join(ConnectorType, ChargerPort.connector_type_id == ConnectorType.id)
        .where(ChargingSession.id == session.id)
    )
    payload = ChargingSessionResponse.model_validate(session).model_dump()
    row = result.one_or_none()
    if row is not None:
        name, address, price, power, connector = row
        payload.update(
            charger_name=name,
            charger_address=address,
            price_per_kwh=float(price),
            power_kw=float(power),
            connector_type=connector,
        )
    return payload


# --- Request Bodies ---


class CheckInRequest(BaseModel):
    """Driver has arrived at the charger and is checking in."""

    booking_id: UUID


class CompleteSessionRequest(BaseModel):
    """Final telemetry sent when the driver unplugs. Cost is calculated server-side."""

    energy_kwh: float = Field(..., ge=0.0, description="Total energy delivered in kWh")


# --- Endpoints ---


@router.get("/", response_model=list[ChargingSessionResponse])
async def list_sessions(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    sessions = await session_repo.get_by_user(db, user_id=user_id)
    return [await _with_charger_context(db, session) for session in sessions]


@router.get("/{session_id}", response_model=ChargingSessionResponse)
async def get_session(
    session_id: UUID,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    session = await session_repo.get(db, id=session_id)
    if session is None or session.user_id != user_id:
        raise HTTPException(status_code=404, detail="Charging session not found")
    return await _with_charger_context(db, session)


@router.post(
    "/check-in", response_model=ChargingSessionResponse, status_code=status.HTTP_201_CREATED
)
async def check_in(
    request: CheckInRequest,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Check in at the charger.
    Creates a charging session. Booking must be CONFIRMED.
    """
    session = await session_service.check_in(db=db, booking_id=request.booking_id, user_id=user_id)
    return await _with_charger_context(db, session)


@router.post("/{session_id}/start", response_model=ChargingSessionResponse)
async def start_charging(
    session_id: UUID,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Mark that charging has begun (plug connected, power flowing).
    Transitions session from checked_in → charging.
    """
    session = await session_service.start_charging(db=db, session_id=session_id, user_id=user_id)
    return await _with_charger_context(db, session)


@router.post("/{session_id}/complete", response_model=ChargingSessionResponse)
async def complete_session(
    session_id: UUID,
    request: CompleteSessionRequest,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Complete the charging session.
    Client sends energy_kwh; cost is calculated server-side from charger pricing.
    """
    session = await session_service.complete_session(
        db=db, session_id=session_id, user_id=user_id, energy_kwh=request.energy_kwh
    )
    return await _with_charger_context(db, session)


@router.post(
    "/{session_id}/rating", response_model=ReviewResponse, status_code=status.HTTP_201_CREATED
)
@router.post(
    "/{session_id}/reviews", response_model=ReviewResponse, status_code=status.HTTP_201_CREATED
)
async def submit_rating(

    session_id: UUID,
    review_in: ReviewCreate,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    if review_in.session_id != session_id:
        raise HTTPException(status_code=422, detail="Session id does not match path")
    session = await session_repo.get(db, id=session_id)
    if session is None or session.user_id != user_id:
        raise HTTPException(status_code=404, detail="Charging session not found")
    if session.status != "completed":
        raise HTTPException(status_code=409, detail="Only completed sessions can be reviewed")
    existing = await review_repo.get_by_session(db, session_id=session_id)
    if existing is not None:
        raise HTTPException(status_code=409, detail="Session already reviewed")
    review = await review_repo.create(
        db,
        obj_in={
            "session_id": session_id,
            "user_id": user_id,
            "rating": review_in.rating,
            "comment": review_in.comment,
            "issue_flags": review_in.issue_flags,
        },
    )
    await db.commit()
    await db.refresh(review)
    return review
