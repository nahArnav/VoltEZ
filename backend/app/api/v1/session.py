from uuid import UUID
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.charging_session import ChargingSessionResponse
from app.services.session import session_service
from app.api.v1.deps import get_current_user_id

router = APIRouter(prefix="/sessions", tags=["Sessions"])


# --- Request Bodies ---

class CheckInRequest(BaseModel):
    """Driver has arrived at the charger and is checking in."""
    booking_id: UUID


class CompleteSessionRequest(BaseModel):
    """Final telemetry sent when the driver unplugs. Cost is calculated server-side."""
    energy_kwh: float = Field(..., ge=0.0, description="Total energy delivered in kWh")


# --- Endpoints ---

@router.post("/check-in", response_model=ChargingSessionResponse, status_code=status.HTTP_201_CREATED)
async def check_in(
    request: CheckInRequest,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Check in at the charger.
    Creates a charging session. Booking must be CONFIRMED.
    """
    session = await session_service.check_in(
        db=db, booking_id=request.booking_id, user_id=user_id
    )
    return session


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
    session = await session_service.start_charging(
        db=db, session_id=session_id, user_id=user_id
    )
    return session


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
    return session