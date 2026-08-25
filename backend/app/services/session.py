from app.schemas.enums import BookingStatus
from uuid import UUID
from datetime import datetime, timezone
from typing import cast
from sqlalchemy.ext.asyncio import AsyncSession


from database.models.booking_event import BookingEvent
from database.models.charging_session import ChargingSession
from app.repositories.session import session_repo
from app.repositories.booking import booking_repo
from app.repositories.charger import charger_port_repo
from app.core.errors import NotFoundError, BadRequestError, ForbiddenError
from app.services.trust import trust_service
from app.services.fcm import fcm_service
from app.websockets.manager import manager

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

        booking_status = BookingStatus(cast(str, booking.status))
        if booking_status != BookingStatus.CONFIRMED:
            raise BadRequestError(
                message=f"Cannot check in. Booking is {booking_status.value}, expected CONFIRMED.",
                code="INVALID_STATE_TRANSITION",
            )

        # 2. Transition booking to CHECKED_IN
        old_status = booking_status.value
        setattr(booking, "status", BookingStatus.CHECKED_IN.value)
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
                charger_port_id=port_id
            )

        await db.commit()
        await db.refresh(new_session)

        # 6. Broadcast Real-time Updates (WebSockets & FCM)
        payload = {
            "event": "session_checked_in",
            "session_id": new_session.id,
            "booking_id": booking.id
        }
        await manager.send_personal_message(payload, user_id)
        await fcm_service.send_push_notification(
            db=db,
            user_id=user_id,
            title="Checked In!",
            body="You have successfully checked in at the charger.",
            payload=payload
        )

        return new_session

    @staticmethod
    async def start_charging(db: AsyncSession, session_id: UUID, user_id: UUID) -> ChargingSession:
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
        if booking_user_id != user_id:
            raise ForbiddenError(message="Not authorized for this session.")

        # 1. Update session
        now = datetime.now(timezone.utc)
        setattr(session, "started_at", now)
        setattr(session, "status", "charging")
        db.add(session)

        # 2. Update booking status
        booking_status = BookingStatus(cast(str, booking.status))
        old_status = booking_status.value
        setattr(booking, "status", BookingStatus.CHARGING.value)
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
            "port_id": booking.charger_port_id
        }
        await manager.send_personal_message(payload, user_id)
        await fcm_service.send_push_notification(
            db=db,
            user_id=user_id,
            title="Charging Started \u26a1",
            body="Your vehicle is now charging.",
            payload=payload
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

        # 1. Calculate cost (pricing should come from another domain)
        rate_per_kwh = 12.0  # fallback rate in INR
        total_cost = round(energy_kwh * rate_per_kwh, 2)

        # 2. Finalize session
        now = datetime.now(timezone.utc)
        setattr(session, "ended_at", now)
        setattr(session, "energy_kwh", energy_kwh)
        setattr(session, "amount", total_cost)
        setattr(session, "status", "completed")
        db.add(session)

        # 3. Complete the booking
        booking_status = BookingStatus(cast(str, booking.status))
        old_status = booking_status.value
        setattr(booking, "status", BookingStatus.COMPLETED.value)
        db.add(booking)

        port = await charger_port_repo.get(db, id=booking.charger_port_id)

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
                charger_port_id=port_id
            )

        await db.commit()
        await db.refresh(session)

        # 7. Broadcast Real-time Updates
        payload = {
            "event": "charging_completed",
            "session_id": session.id,
            "energy_kwh": energy_kwh,
            "final_amount": total_cost
        }
        await manager.send_personal_message(payload, user_id)
        await fcm_service.send_push_notification(
            db=db,
            user_id=user_id,
            title="Charging Completed \u2705",
            body=f"Session ended. Total cost: ₹{total_cost}",
            payload=payload
        )

        return session


session_service = SessionService()