from datetime import UTC, datetime, timedelta
from typing import cast
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import BadRequestError, ConflictError, ForbiddenError, NotFoundError
from app.repositories.booking import booking_repo
from app.repositories.charger import charger_port_repo
from app.schemas.booking import BookingCreate
from app.schemas.enums import BookingStatus
from app.services.availability import availability_service
from app.services.pricing import dynamic_rate_from_signals
from database.models.booking import Booking
from database.models.booking_event import BookingEvent
from database.models.charger import Charger
from database.models.charger_port import ChargerPort
from database.models.user import User


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

        current_time = datetime.now(UTC)
        user = await db.get(User, user_id)
        if user is None:
            raise NotFoundError(resource="User")
        if user.suspended_until and user.suspended_until > current_time:
            raise ForbiddenError(
                message=(
                    "Booking is temporarily suspended after repeated late cancellations. "
                    f"Try again after {user.suspended_until.isoformat()}."
                ),
            )

        # 1. Verify the port actually exists
        port = await charger_port_repo.get(db, id=booking_in.charger_port_id)
        if not port:
            raise NotFoundError(resource="ChargerPort")

        charger = await db.get(Charger, port.charger_id)
        if charger is None:
            raise NotFoundError(resource="Charger")
        if charger.status != "available":
            raise BadRequestError(
                message="This charger is not currently accepting bookings.",
                code="CHARGER_NOT_AVAILABLE",
            )

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
        active_bookings = await booking_repo.get_active_by_port(
            db, port_id=cast(UUID, port.id), current_time=current_time
        )

        for existing_booking in active_bookings:
            existing_start_at = cast(datetime, existing_booking.start_at)
            existing_end_at = cast(datetime, existing_booking.end_at)
            # Overlap logic: A starts before B ends AND A ends after B starts
            if (booking_in.start_at < existing_end_at) and (booking_in.end_at > existing_start_at):
                raise ConflictError(
                    code="SLOT_UNAVAILABLE",
                    message="This time slot overlaps with an existing booking.",
                )

        # Lock the quoted tariff into the booking.  The rate is bounded and
        # calculated server-side from the station base tariff plus current
        # demand/occupancy pressure; clients cannot alter the payable rate.
        base_rate = await db.scalar(
            select(Charger.price_per_kwh)
            .join(ChargerPort, ChargerPort.charger_id == Charger.id)
            .where(ChargerPort.id == port.id)
        )
        active_port_count = await db.scalar(
            select(func.count(ChargerPort.id)).where(
                ChargerPort.charger_id == port.charger_id,
                ChargerPort.is_active.is_(True),
            )
        )
        quote = dynamic_rate_from_signals(
            base_rate=float(base_rate or settings.DEFAULT_PRICE_PER_KWH_INR),
            expected_demand=float(len(active_bookings)),
            probability_unavailable=(
                min(len(active_bookings) / max(int(active_port_count or 1), 1), 1.0)
            ),
            active_ports=max(int(active_port_count or 1), 1),
            target_time=booking_in.start_at,
        )

        # 4. Create the booking record
        booking_data = booking_in.model_dump()
        booking_data["user_id"] = user_id
        booking_data["status"] = BookingStatus.HELD.value
        booking_data["estimated_amount"] = settings.BOOKING_HOLD_FEE_INR
        booking_data["quoted_price_per_kwh"] = quote.effective_rate

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
        now = datetime.now(UTC)
        booking.status = BookingStatus.CANCELLED.value
        booking.cancelled_at = now
        db.add(booking)

        # Cancellation policy: Free cancellation >= 15 min before start; late penalty if < 15 min
        is_late = (booking.start_at - now) < timedelta(minutes=15)
        penalty_fee = 50.0 if is_late else 0.0
        user = await db.get(User, user_id)
        if user is None:
            raise NotFoundError(resource="User")
        if is_late:
            user.cancellation_strikes = (user.cancellation_strikes or 0) + 1
            user.penalty_points = (user.penalty_points or 0) + 10
            if user.cancellation_strikes >= 3:
                user.suspended_until = now + timedelta(days=7)
            db.add(user)

        # Write audit event (BR-009)
        event = BookingEvent(
            booking_id=booking.id,
            old_status=old_status,
            new_status=BookingStatus.CANCELLED.value,
            actor=f"user:{user_id}",
            metadata_={
                "reason": "user_cancelled",
                "late_cancellation": is_late,
                "penalty_fee_inr": penalty_fee,
                "cancellation_strikes": user.cancellation_strikes,
                "penalty_points": user.penalty_points,
                "suspended_until": user.suspended_until.isoformat() if user.suspended_until else None,
                "cancelled_at": now.isoformat(),
            },
        )
        db.add(event)

        await db.commit()
        await db.refresh(booking)
        return booking
    @staticmethod
    async def cancel_business_booking(
        db: AsyncSession, booking_id: UUID, user_id: UUID
    ) -> Booking:
        """Business logic for a host/business canceling a booking."""
        booking = await booking_repo.get(db, id=booking_id)
        if not booking:
            raise NotFoundError(resource="Booking")

        booking_status = BookingStatus(cast(str, booking.status))
        if booking_status not in BookingService.CANCELLABLE_STATUSES:
            raise BadRequestError(
                message=f"Cannot cancel a booking that is {booking_status.value}.",
                code="INVALID_STATE_TRANSITION",
            )

        old_status = booking_status.value
        now = datetime.now(UTC)
        booking.status = BookingStatus.CANCELLED.value
        booking.cancelled_at = now
        db.add(booking)

        event = BookingEvent(
            booking_id=booking.id,
            old_status=old_status,
            new_status=BookingStatus.CANCELLED.value,
            actor=f"business_user:{user_id}",
            metadata_={
                "reason": "business_cancelled",
                "cancelled_at": now.isoformat(),
            },
        )
        db.add(event)

        await db.commit()
        await db.refresh(booking)
        return booking

booking_service = BookingService()
