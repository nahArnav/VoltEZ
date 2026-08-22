from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.booking import BookingStatus
from app.models.booking_event import BookingEvent
from app.models.charging_session import ChargingSession
from app.repositories.session import session_repo
from app.repositories.booking import booking_repo
from app.repositories.charger import charger_port_repo
from app.core.errors import NotFoundError, BadRequestError, ForbiddenError


class SessionService:

    @staticmethod
    async def check_in(db: AsyncSession, booking_id: int, user_id: int) -> ChargingSession:
        """Check in at the charger — creates a session record and transitions booking to CHECKED_IN."""

        # 1. Validate the booking
        booking = await booking_repo.get(db, id=booking_id)
        if not booking:
            raise NotFoundError(resource="Booking")

        if booking.user_id != user_id:
            raise ForbiddenError(message="Not authorized to check in for this booking.")

        if booking.status != BookingStatus.CONFIRMED:
            raise BadRequestError(
                message=f"Cannot check in. Booking is {booking.status.value}, expected CONFIRMED.",
                code="INVALID_STATE_TRANSITION",
            )

        # 2. Transition booking to CHECKED_IN
        old_status = booking.status.value
        booking.status = BookingStatus.CHECKED_IN
        db.add(booking)

        # 3. Write audit event (BR-009)
        event = BookingEvent(
            booking_id=booking.id,
            old_status=old_status,
            new_status=BookingStatus.CHECKED_IN.value,
            actor=f"user:{user_id}",
        )
        db.add(event)

        # 4. Create the session record
        now = datetime.now(timezone.utc)
        new_session = ChargingSession(
            booking_id=booking.id,
            check_in_at=now,
            status="checked_in",
        )
        db.add(new_session)

        await db.commit()
        await db.refresh(new_session)
        return new_session

    @staticmethod
    async def start_charging(db: AsyncSession, session_id: int, user_id: int) -> ChargingSession:
        """Mark that charging has actually begun (plug connected, power flowing)."""

        session = await session_repo.get(db, id=session_id)
        if not session:
            raise NotFoundError(resource="ChargingSession")

        if session.status != "checked_in":
            raise BadRequestError(
                message=f"Cannot start charging. Session is {session.status}, expected checked_in.",
                code="INVALID_STATE_TRANSITION",
            )

        booking = await booking_repo.get(db, id=session.booking_id)
        if not booking or booking.user_id != user_id:
            raise ForbiddenError(message="Not authorized for this session.")

        # 1. Update session
        now = datetime.now(timezone.utc)
        session.start_at = now
        session.status = "charging"
        db.add(session)

        # 2. Update booking status
        old_status = booking.status.value
        booking.status = BookingStatus.CHARGING
        db.add(booking)

        # 3. Update port status
        port = await charger_port_repo.get(db, id=booking.port_id)
        if port:
            port.status = "occupied"
            db.add(port)

        # 4. Audit event (BR-009)
        event = BookingEvent(
            booking_id=booking.id,
            old_status=old_status,
            new_status=BookingStatus.CHARGING.value,
            actor=f"user:{user_id}",
        )
        db.add(event)

        await db.commit()
        await db.refresh(session)
        return session

    @staticmethod
    async def complete_session(
        db: AsyncSession, session_id: int, user_id: int, energy_kwh: float
    ) -> ChargingSession:
        """Complete the charging session, calculate cost, and free the port."""

        session = await session_repo.get(db, id=session_id)
        if not session or session.status != "charging":
            raise NotFoundError(resource="Active charging session")

        booking = await booking_repo.get(db, id=session.booking_id)
        if not booking or booking.user_id != user_id:
            raise ForbiddenError(message="Not authorized for this session.")

        if energy_kwh < 0:
            raise BadRequestError(message="Energy delivered cannot be negative.")

        # 1. Calculate cost from the charger's base_price
        # In production this would come from the quote_snapshot or charger settings
        port = await charger_port_repo.get(db, id=booking.port_id)
        rate_per_kwh = 12.0  # fallback rate in INR
        if port and port.charger:
            rate_per_kwh = port.charger.base_price or rate_per_kwh
        total_cost = round(energy_kwh * rate_per_kwh, 2)

        # 2. Finalize session
        now = datetime.now(timezone.utc)
        session.end_at = now
        session.energy_kwh = energy_kwh
        session.final_amount = total_cost
        session.status = "completed"
        db.add(session)

        # 3. Complete the booking
        old_status = booking.status.value
        booking.status = BookingStatus.COMPLETED
        db.add(booking)

        # 4. Free up the port
        if port:
            port.status = "available"
            db.add(port)

        # 5. Audit event (BR-009)
        event = BookingEvent(
            booking_id=booking.id,
            old_status=old_status,
            new_status=BookingStatus.COMPLETED.value,
            actor=f"user:{user_id}",
            metadata_={"energy_kwh": energy_kwh, "final_amount": total_cost},
        )
        db.add(event)

        await db.commit()
        await db.refresh(session)
        return session


session_service = SessionService()