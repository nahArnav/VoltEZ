from datetime import UTC, datetime, timedelta
from typing import cast
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import BadRequestError, ForbiddenError, NotFoundError
from app.repositories.booking import booking_repo
from app.repositories.charger import charger_port_repo
from app.repositories.session import session_repo
from app.schemas.enums import BookingStatus
from app.services.cash import matches_cash_otp
from app.services.fcm import fcm_service
from app.services.trust import trust_service
from app.websockets.manager import manager
from database.models.booking_event import BookingEvent
from database.models.charger import Charger
from database.models.charging_session import ChargingSession


class SessionService:
    @staticmethod
    async def check_in(db: AsyncSession, booking_id: UUID, user_id: UUID) -> ChargingSession:
        """Check in at the charger — creates a session record and transitions booking to CHECKED_IN."""

        # 1. Validate the booking
        booking = await booking_repo.get(db, id=booking_id)
        if not booking:
            raise NotFoundError(resource="Booking")

        booking_user_id = booking.user_id
        if booking_user_id != user_id:
            raise ForbiddenError(message="Not authorized to check in for this booking.")

        # Owner OTP verification may have already created/started the session
        # while the driver was on the confirmation screen. Treat a subsequent
        # driver tap as an idempotent read instead of rejecting a valid cash
        # booking because its status is now CHARGING.
        existing_session = await session_repo.get_by_booking(db, booking_id=booking.id)
        if existing_session is not None and existing_session.status in {
            "reserved",
            "charging",
            "completed",
        }:
            return existing_session

        booking_status = BookingStatus(cast(str, booking.status))
        if booking_status != BookingStatus.CONFIRMED:
            raise BadRequestError(
                message=f"Cannot check in. Booking is {booking_status.value}, expected CONFIRMED.",
                code="INVALID_STATE_TRANSITION",
            )

        now = datetime.now(UTC)
        if now < booking.start_at - timedelta(minutes=30):
            raise BadRequestError(
                message="Check-in opens 30 minutes before your reserved start time.",
                code="CHECKIN_TOO_EARLY",
            )
        if now > booking.end_at + timedelta(minutes=30):
            raise BadRequestError(
                message="This reservation's check-in window has expired.",
                code="CHECKIN_WINDOW_EXPIRED",
            )

        # 2. Transition booking to CHECKED_IN
        old_status = booking_status.value
        booking.status = BookingStatus.CHECKED_IN.value
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
        new_session = ChargingSession(
            charger_port_id=booking.charger_port_id,
            user_id=user_id,
            booking_id=booking.id,
            reserved_at=now,
            status="reserved",
        )
        db.add(new_session)

        # 5. Record trust event
        port = await charger_port_repo.get(db, id=booking.charger_port_id)
        if port:
            port_charger_id = cast(UUID, port.charger_id)
            port_id = cast(UUID, port.id)
            await trust_service.record_event(
                db,
                charger_id=port_charger_id,
                status="occupied",
                source="DRIVER_CHECKIN",
                confidence=0.9,
                charger_port_id=port_id,
            )

        await db.commit()
        await db.refresh(new_session)

        # 6. Broadcast Real-time Updates (WebSockets & FCM)
        payload = {
            "event": "session_checked_in",
            "session_id": new_session.id,
            "booking_id": booking.id,
        }
        await manager.send_personal_message(payload, user_id)
        await fcm_service.send_push_notification(
            db=db,
            user_id=user_id,
            title="Checked In!",
            body="You have successfully checked in at the charger.",
            payload=payload,
        )

        return new_session

    @staticmethod
    async def start_charging(db: AsyncSession, session_id: UUID, user_id: UUID, otp: str | None = None) -> ChargingSession:
        """Mark that charging has actually begun (plug connected, power flowing)."""

        session = await session_repo.get(db, id=session_id)
        if not session:
            raise NotFoundError(resource="ChargingSession")

        session_status = cast(str, session.status)
        if session_status != "reserved":
            raise BadRequestError(
                message=f"Cannot start charging. Session is {session_status}, expected reserved.",
                code="INVALID_STATE_TRANSITION",
            )

        booking = await booking_repo.get(db, id=session.booking_id)
        if not booking:
            raise ForbiddenError(message="Not authorized for this session.")

        booking_user_id = booking.user_id
        is_owner = False
        
        # Check if user is the business owner
        if booking_user_id != user_id:
            port = await charger_port_repo.get(db, id=booking.charger_port_id)
            if port:
                charger = await db.get(Charger, port.charger_id)
                if charger and charger.business_id:
                    from database.models.business import Business
                    business = await db.get(Business, charger.business_id)
                    if business and business.owner_id == user_id:
                        is_owner = True
                        
        if booking_user_id != user_id and not is_owner:
            raise ForbiddenError(message="Not authorized for this session.")

        # If it's a cash booking, verify OTP
        if booking.cash_otp_hash:
            if not otp:
                raise BadRequestError(message="Cash payment requires an OTP to start charging.")
            if not matches_cash_otp(booking, otp):
                booking.cash_otp_attempts += 1
                db.add(booking)
                await db.commit()
                raise BadRequestError(message="Invalid OTP.")
            booking.cash_otp_verified_at = datetime.now(UTC)

        # 1. Update session
        now = datetime.now(UTC)
        session.started_at = now
        session.status = "charging"
        db.add(session)

        # 2. Update booking status
        booking_status = BookingStatus(cast(str, booking.status))
        old_status = booking_status.value
        booking.status = BookingStatus.CHARGING.value
        db.add(booking)

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

        # 5. Broadcast Real-time Updates
        payload = {
            "event": "charging_started",
            "session_id": session.id,
            "port_id": booking.charger_port_id,
        }
        await manager.send_personal_message(payload, user_id)
        await fcm_service.send_push_notification(
            db=db,
            user_id=user_id,
            title="Charging Started \u26a1",
            body="Your vehicle is now charging.",
            payload=payload,
        )

        return session

    @staticmethod
    async def complete_session(
        db: AsyncSession, session_id: UUID, user_id: UUID, energy_kwh: float
    ) -> ChargingSession:
        """Complete the charging session, calculate cost, and free the port."""

        session = await session_repo.get(db, id=session_id)
        if not session:
            raise NotFoundError(resource="Active charging session")

        session_status = cast(str, session.status)
        if session_status != "charging":
            raise NotFoundError(resource="Active charging session")

        booking = await booking_repo.get(db, id=session.booking_id)
        if not booking:
            raise ForbiddenError(message="Not authorized for this session.")

        booking_user_id = booking.user_id
        if booking_user_id != user_id:
            raise ForbiddenError(message="Not authorized for this session.")

        if energy_kwh < 0:
            raise BadRequestError(message="Energy delivered cannot be negative.")

        # 1. Calculate cost from the station's persisted tariff.  The global
        # setting is only a safe fallback for legacy chargers created before
        # the tariff column existed; it must never override a station price.
        port = await charger_port_repo.get(db, id=booking.charger_port_id)
        rate_per_kwh = float(booking.quoted_price_per_kwh or settings.DEFAULT_PRICE_PER_KWH_INR)
        if port is not None and booking.quoted_price_per_kwh is None:
            charger_result = await db.execute(
                select(Charger.price_per_kwh).where(Charger.id == port.charger_id)
            )
            charger_rate = charger_result.scalar_one_or_none()
            if charger_rate is not None:
                rate_per_kwh = float(charger_rate)
        total_cost = round(energy_kwh * rate_per_kwh, 2)

        # 2. Finalize session
        now = datetime.now(UTC)
        session.ended_at = now
        session.energy_kwh = energy_kwh
        session.amount = total_cost
        session.status = "completed"
        db.add(session)

        # 3. Complete the booking
        booking_status = BookingStatus(cast(str, booking.status))
        old_status = booking_status.value
        booking.status = BookingStatus.COMPLETED.value
        db.add(booking)

        # 5. Audit event (BR-009)
        event = BookingEvent(
            booking_id=booking.id,
            old_status=old_status,
            new_status=BookingStatus.COMPLETED.value,
            actor=f"user:{user_id}",
            metadata_={"energy_kwh": energy_kwh, "final_amount": total_cost},
        )
        db.add(event)

        # 6. Record trust event
        if port:
            port_charger_id = cast(UUID, port.charger_id)
            port_id = cast(UUID, port.id)
            await trust_service.record_event(
                db,
                charger_id=port_charger_id,
                status="available",
                source="DRIVER_CHECKOUT",
                confidence=0.9,
                charger_port_id=port_id,
            )

        await db.commit()
        await db.refresh(session)

        # 7. Broadcast Real-time Updates
        payload = {
            "event": "charging_completed",
            "session_id": session.id,
            "energy_kwh": energy_kwh,
            "final_amount": total_cost,
        }
        await manager.send_personal_message(payload, user_id)
        await fcm_service.send_push_notification(
            db=db,
            user_id=user_id,
            title="Charging Completed \u2705",
            body=f"Session ended. Total cost: ₹{total_cost}",
            payload=payload,
        )

        return session


session_service = SessionService()
