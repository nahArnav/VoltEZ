from datetime import datetime, timezone
from typing import List
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.booking import Booking, BookingStatus
from app.models.booking_event import BookingEvent
from app.schemas.booking import BookingCreate
from app.repositories.booking import booking_repo
from app.repositories.charger import charger_port_repo
from app.core.errors import NotFoundError, ConflictError, BadRequestError, ForbiddenError


class BookingService:

    # Valid cancellation source statuses (BR-008)
    CANCELLABLE_STATUSES = {
        BookingStatus.PENDING,
        BookingStatus.HELD,
        BookingStatus.PAYMENT_PENDING,
        BookingStatus.CONFIRMED,
    }

    @staticmethod
    async def create_booking(db: AsyncSession, user_id: int, booking_in: BookingCreate) -> Booking:
        """Business logic for reserving a charger port."""

        # 1. Verify the port actually exists
        port = await charger_port_repo.get(db, id=booking_in.port_id)
        if not port:
            raise NotFoundError(resource="ChargerPort")

        # 2. Check if the port is currently operational
        if port.status != "available":
            raise BadRequestError(
                message=f"This port is currently {port.status} and cannot be booked.",
                code="PORT_NOT_AVAILABLE",
            )

        # 3. Prevent Double-Bookings (Time Conflict Check)
        current_time = datetime.now(timezone.utc)
        active_bookings = await booking_repo.get_active_by_port(
            db, port_id=port.id, current_time=current_time
        )

        for existing_booking in active_bookings:
            # Overlap logic: A starts before B ends AND A ends after B starts
            if (booking_in.start_at < existing_booking.end_at) and (
                booking_in.end_at > existing_booking.start_at
            ):
                raise ConflictError(
                    code="SLOT_UNAVAILABLE",
                    message="This time slot overlaps with an existing booking.",
                )

        # 4. Create the booking record
        booking_data = booking_in.model_dump()
        booking_data["user_id"] = user_id
        booking_data["status"] = BookingStatus.PENDING

        db_booking = Booking(**booking_data)
        db.add(db_booking)
        await db.flush()
        await db.refresh(db_booking)

        # 5. Write audit event (BR-009)
        event = BookingEvent(
            booking_id=db_booking.id,
            old_status=None,
            new_status=BookingStatus.PENDING.value,
            actor=f"user:{user_id}",
        )
        db.add(event)

        await db.commit()
        return db_booking

    @staticmethod
    async def cancel_booking(db: AsyncSession, booking_id: int, user_id: int) -> Booking:
        """Business logic for canceling a booking."""
        booking = await booking_repo.get(db, id=booking_id)

        if not booking:
            raise NotFoundError(resource="Booking")

        # Ensure a user is only canceling THEIR OWN booking
        if booking.user_id != user_id:
            raise ForbiddenError(message="Not authorized to cancel this booking.")

        if booking.status not in BookingService.CANCELLABLE_STATUSES:
            raise BadRequestError(
                message=f"Cannot cancel a booking that is {booking.status.value}.",
                code="INVALID_STATE_TRANSITION",
            )

        old_status = booking.status.value
        booking.status = BookingStatus.CANCELLED
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