from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.booking import BookingCreate, BookingResponse
from app.services.booking import booking_service
from app.api.v1.deps import get_current_user_id

router = APIRouter(prefix="/bookings", tags=["Bookings"])


@router.post("/", response_model=BookingResponse, status_code=status.HTTP_201_CREATED)
async def create_booking(
    booking_in: BookingCreate,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Reserve a charger port.
    Requires a valid JWT access token.
    """
    booking = await booking_service.create_booking(db=db, user_id=user_id, booking_in=booking_in)
    return booking


@router.post("/{booking_id}/cancel", response_model=BookingResponse)
async def cancel_booking(
    booking_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Cancel an existing booking.
    Users can only cancel their own bookings.
    """
    booking = await booking_service.cancel_booking(db=db, booking_id=booking_id, user_id=user_id)
    return booking