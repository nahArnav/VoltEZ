from datetime import timedelta
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_current_user_id
from app.db.session import get_db
from app.schemas.booking import BookingCreate, BookingResponse
from app.services.booking import booking_service
from database.models.booking import Booking
from database.models.charger import Charger
from database.models.charger_port import ChargerPort
from database.models.connector import ConnectorType

router = APIRouter(prefix="/bookings", tags=["Bookings"])


async def _with_charger_context(db: AsyncSession, booking: Booking) -> dict:
    """Expose station context so clients do not render fabricated labels."""
    context = await db.execute(
        select(
            Charger.name,
            Charger.address_text,
            Charger.price_per_kwh,
            Booking.quoted_price_per_kwh,
            ChargerPort.max_power_kw,
            ConnectorType.display_name,
        )
        .select_from(Booking)
        .join(ChargerPort, Booking.charger_port_id == ChargerPort.id)
        .join(Charger, ChargerPort.charger_id == Charger.id)
        .join(ConnectorType, ChargerPort.connector_type_id == ConnectorType.id)
        .where(Booking.id == booking.id)
    )
    row = context.one_or_none()
    payload = BookingResponse.model_validate(booking).model_dump()
    if row is not None:
        name, address, price, quoted_price, power, connector = row
        payload.update(
            charger_name=name,
            charger_address=address,
            price_per_kwh=float(quoted_price or price),
            quoted_price_per_kwh=float(quoted_price) if quoted_price is not None else None,
            power_kw=float(power),
            connector_type=connector,
        )
    return payload


@router.get("/", response_model=list[BookingResponse])
async def list_bookings(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    bookings = await booking_service.list_bookings(db=db, user_id=user_id)
    return [await _with_charger_context(db, booking) for booking in bookings]


@router.get("/{booking_id}", response_model=BookingResponse)
async def get_booking(
    booking_id: UUID,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    booking = await booking_service.get_booking(db=db, booking_id=booking_id, user_id=user_id)
    if booking is None:
        raise HTTPException(status_code=404, detail="Booking not found")
    return await _with_charger_context(db, booking)


@router.post("/", response_model=BookingResponse, status_code=status.HTTP_201_CREATED)
async def create_booking(
    request: Request,
    booking_in: BookingCreate,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Reserve a charger port.
    Requires a valid JWT access token.
    """
    redis = request.app.state.redis

    # Step 2.2: Implement atomic Redis hold locking with a 10-minute TTL
    # The lock key is scoped to the exact port and time slot to prevent UI double-booking
    lock_key = f"hold:port:{booking_in.charger_port_id}:{int(booking_in.start_at.timestamp())}:{int(booking_in.end_at.timestamp())}"

    # SET NX with 10 minutes (600 seconds) TTL
    acquired = await redis.set(lock_key, str(user_id), nx=True, ex=600)

    if not acquired:
        from fastapi import HTTPException

        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="SLOT_UNAVAILABLE")

    try:
        # 1. Create the booking in the database
        booking = await booking_service.create_booking(
            db=db, user_id=user_id, booking_in=booking_in
        )

        # 2. Tell Redis to wake up in 10 minutes (600s) and check this booking.
        await redis.enqueue_job(
            "expire_unpaid_booking", str(booking.id), _defer_by=timedelta(minutes=10)
        )

        await db.commit()
        await db.refresh(booking)
        return await _with_charger_context(db, booking)
    except Exception:
        # If DB creation fails (e.g. overlap check fails), release the lock
        await db.rollback()
        await redis.delete(lock_key)
        raise


@router.post("/{booking_id}/cancel", response_model=BookingResponse)
async def cancel_booking(
    request: Request,
    booking_id: UUID,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Cancel an existing booking.
    Users can only cancel their own bookings.
    """
    booking = await booking_service.cancel_booking(db=db, booking_id=booking_id, user_id=user_id)
    lock_key = (
        f"hold:port:{booking.charger_port_id}:"
        f"{int(booking.start_at.timestamp())}:{int(booking.end_at.timestamp())}"
    )
    await request.app.state.redis.delete(lock_key)
    return await _with_charger_context(db, booking)
