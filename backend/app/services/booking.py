from app.schemas.enums import BookingStatus
from uuid import UUID
from datetime import datetime, timezone, timedelta
from typing import cast
from sqlalchemy.ext.asyncio import AsyncSession

from database.models.booking import Booking
from database.models.booking_event import BookingEvent
from app.schemas.booking import BookingCreate
from app.repositories.booking import booking_repo
from app.repositories.charger import charger_port_repo
from app.core.errors import NotFoundError, ConflictError, BadRequestError, ForbiddenError
from app.core.config import settings
from app.services.availability import availability_service


class BookingService:

    # Valid cancellation source statuses (BR-008)
    CANCELLABLE_STATUSES = {
        BookingStatus.PENDING,
        BookingStatus.HELD,
        BookingStatus.CONFIRMED,
    }

    @staticmethod
    async def list_bookings(db: AsyncSession, user_id: UUID) -> list[Booking]:
        return await booking_repo.get_by_user(db, user_id=user_id)

    @staticmethod
    async def get_booking(
        db: AsyncSession,
        booking_id: UUID,
        user_id: UUID,
    ) -> Booking | None:
        booking = await booking_repo.get(db, id=booking_id)
        if booking is None or booking.user_id != user_id:
            return None
        return booking

    @staticmethod
    async def create_booking(db: AsyncSession, user_id: UUID, booking_in: BookingCreate) -> Booking:
        """Business logic for reserving a charger port."""

        # 1. Verify the port actually exists
        port = await charger_port_repo.get(db, id=booking_in.charger_port_id)
        if not port:
            raise NotFoundError(resource="ChargerPort")

        # 2. Check if the port is currently operational
        if not port.is_active:
            raise BadRequestError(
                message="This port is not currently active and cannot be booked.",
                code="PORT_NOT_AVAILABLE",
            )

        if not await availability_service.is_slot_bookable(
            db,
            cast(UUID, port.id),
            booking_in.start_at,
            booking_in.end_at,
        ):
            raise ConflictError(
                code="OUTSIDE_AVAILABILITY",
                message="This slot is outside the owner's approved availability.",
            )

        # 3. Prevent Double-Bookings (Time Conflict Check)
        current_time = datetime.now(timezone.utc)
        active_bookings = await booking_repo.get_active_by_port(
            db, port_id=cast(UUID, port.id), current_time=current_time
        )

        for existing_booking in active_bookings:
            existing_start_at = cast(datetime, existing_booking.start_at)
            existing_end_at = cast(datetime, existing_booking.end_at)
            # Overlap logic: A starts before B ends AND A ends after B starts
            if (booking_in.start_at < existing_end_at) and (
                booking_in.end_at > existing_start_at
            ):
                raise ConflictError(
                    code="SLOT_UNAVAILABLE",
                    message="This time slot overlaps with an existing booking.",
                )

        # 4. Create the booking record
        booking_data = booking_in.model_dump()
        booking_data["user_id"] = user_id
        booking_data["status"] = BookingStatus.HELD.value
        booking_data["estimated_amount"] = settings.BOOKING_HOLD_FEE_INR
        
        # Set the 10-minute hold expiry
        booking_data["hold_expires_at"] = current_time + timedelta(minutes=10)

        db_booking = Booking(**booking_data)
        db.add(db_booking)
        await db.flush()
        await db.refresh(db_booking)

        # 5. Write audit event (BR-009)
        event = BookingEvent(
            booking_id=db_booking.id,
            old_status=None,
            new_status=BookingStatus.HELD.value,
            actor=f"user:{user_id}",
        )
        db.add(event)

        await db.flush()
        await db.refresh(db_booking)
        return db_booking

    @staticmethod
    async def cancel_booking(db: AsyncSession, booking_id: UUID, user_id: UUID) -> Booking:
        """Business logic for canceling a booking."""
        booking = await booking_repo.get(db, id=booking_id)

        if not booking:
            raise NotFoundError(resource="Booking")

        # Ensure a user is only canceling THEIR OWN booking
        booking_user_id = booking.user_id
        if booking_user_id != user_id:
            raise ForbiddenError(message="Not authorized to cancel this booking.")

        booking_status = BookingStatus(cast(str, booking.status))
        if booking_status not in BookingService.CANCELLABLE_STATUSES:
            raise BadRequestError(
                message=f"Cannot cancel a booking that is {booking_status.value}.",
                code="INVALID_STATE_TRANSITION",
            )

        old_status = booking_status.value
        setattr(booking, "status", BookingStatus.CANCELLED.value)
        db.add(booking)

        # Write audit event (BR-009)
        event = BookingEvent(
            booking_id=booking.id,
            old_status=old_status,
            new_status=BookingStatus.CANCELLED.value,
            actor=f"user:{user_id}",
            metadata_={"reason": "user_cancelled"},
        )
        db.add(event)

        await db.commit()
        await db.refresh(booking)
        return booking


booking_service = BookingService()
