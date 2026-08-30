"""Cash reservation verification and settlement workflows."""

from datetime import UTC, datetime
from typing import cast
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import BadRequestError, ConflictError, NotFoundError
from app.repositories.payment import payment_repo
from app.repositories.session import session_repo
from app.schemas.enums import BookingStatus
from app.services.cash import matches_cash_otp
from app.services.fcm import fcm_service
from app.services.trust import trust_service
from app.websockets.manager import manager
from database.models.booking import Booking
from database.models.booking_event import BookingEvent
from database.models.charger import Charger
from database.models.charger_port import ChargerPort
from database.models.charging_session import ChargingSession
from database.models.payment import Payment


class CashFlowService:
    @staticmethod
    async def verify_otp_and_start(
        db: AsyncSession,
        *,
        business_id: UUID,
        booking_id: UUID,
        code: str,
    ) -> tuple[Booking, ChargingSession]:
        """Verify the host-entered code and start the physical session.

        The booking row is locked for the entire transition. This makes a
        repeated tap, two host devices, or a network retry idempotent and
        prevents the same code from starting two sessions.
        """

        result = await db.execute(
            select(Booking)
            .join(ChargerPort, Booking.charger_port_id == ChargerPort.id)
            .join(Charger, ChargerPort.charger_id == Charger.id)
            .where(Booking.id == booking_id, Charger.business_id == business_id)
            .with_for_update()
        )
        booking = result.scalar_one_or_none()
        if booking is None:
            raise NotFoundError(resource="Booking")

        payment = await payment_repo.get_by_booking(db, booking_id=booking.id)
        if payment is None or payment.method != "cash":
            raise ConflictError(
                code="CASH_PAYMENT_REQUIRED",
                message="This booking is not a pay-at-charger cash reservation.",
            )

        # A successful request is safe to retry. Return the existing session
        # rather than creating a second row or changing its start time.
        existing_session = await session_repo.get_by_booking(db, booking_id=booking.id)
        if booking.cash_otp_verified_at is not None and existing_session is not None:
            return booking, existing_session

        allowed_statuses = {
            BookingStatus.CONFIRMED.value,
            BookingStatus.CHECKED_IN.value,
        }
        if booking.status not in allowed_statuses:
            raise ConflictError(
                code="INVALID_CASH_BOOKING_STATE",
                message=f"Cash OTP cannot be verified for a {booking.status} booking.",
            )

        now = datetime.now(UTC)
        if booking.cash_otp_expires_at is None or booking.cash_otp_expires_at <= now:
            raise BadRequestError(
                message="This cash verification code has expired. Ask the driver to create a new reservation code.",
                code="CASH_OTP_EXPIRED",
            )
        if booking.cash_otp_attempts >= settings.CASH_OTP_MAX_ATTEMPTS:
            raise BadRequestError(
                message="Too many incorrect code attempts. This reservation needs a new code.",
                code="CASH_OTP_LOCKED",
            )
        if not matches_cash_otp(booking, code):
            booking.cash_otp_attempts += 1
            db.add(booking)
            await db.commit()
            raise BadRequestError(
                message="The verification code is incorrect.",
                code="CASH_OTP_INVALID",
            )

        booking.cash_otp_verified_at = now
        # Clear the digest once consumed. The timestamp remains as the audit
        # fact and makes replay requests idempotent without retaining a secret.
        booking.cash_otp_hash = None
        old_status = cast(str, booking.status)
        booking.status = BookingStatus.CHARGING.value
        db.add(booking)

        if existing_session is None:
            session = ChargingSession(
                charger_port_id=booking.charger_port_id,
                user_id=booking.user_id,
                booking_id=booking.id,
                reserved_at=now,
                started_at=now,
                status="charging",
            )
            db.add(session)
        else:
            session = existing_session
            session.started_at = session.started_at or now
            session.status = "charging"
            db.add(session)

        db.add(
            BookingEvent(
                booking_id=booking.id,
                old_status=old_status,
                new_status=BookingStatus.CHARGING.value,
                actor="owner:cash-otp",
                metadata_={"cash_otp_verified": True, "payment_method": "cash"},
            )
        )

        port = await db.get(ChargerPort, booking.charger_port_id)
        if port is not None:
            await trust_service.record_event(
                db,
                charger_id=cast(UUID, port.charger_id),
                charger_port_id=cast(UUID, port.id),
                status="occupied",
                source="OWNER_CASH_OTP",
                confidence=0.95,
            )

        await db.commit()
        await db.refresh(session)

        payload = {
            "event": "cash_otp_verified",
            "booking_id": booking.id,
            "session_id": session.id,
        }
        await manager.send_personal_message(payload, booking.user_id)
        await fcm_service.send_push_notification(
            db=db,
            user_id=booking.user_id,
            title="Charging started",
            body="The host verified your cash code. Your charging session is now active.",
            payload=payload,
        )
        return booking, session

    @staticmethod
    async def settle_cash(
        db: AsyncSession,
        *,
        business_id: UUID,
        booking_id: UUID,
        actor_id: UUID,
    ) -> Payment:
        """Record that the host received cash after a completed session."""

        result = await db.execute(
            select(Payment)
            .join(Booking, Payment.booking_id == Booking.id)
            .join(ChargerPort, Booking.charger_port_id == ChargerPort.id)
            .join(Charger, ChargerPort.charger_id == Charger.id)
            .where(Payment.booking_id == booking_id, Charger.business_id == business_id)
            .with_for_update()
        )
        payment = result.scalar_one_or_none()
        if payment is None:
            raise NotFoundError(resource="Cash payment")
        if payment.method != "cash":
            raise ConflictError(
                code="CASH_PAYMENT_REQUIRED",
                message="This booking does not use cash settlement.",
            )

        booking = await db.get(Booking, booking_id)
        session = await session_repo.get_by_booking(db, booking_id=booking_id)
        if booking is None or session is None:
            raise NotFoundError(resource="Charging session")
        if booking.status != BookingStatus.COMPLETED.value or session.status != "completed":
            raise ConflictError(
                code="CASH_SETTLEMENT_TOO_EARLY",
                message="Cash can be marked received only after the charging session is complete.",
            )
        if payment.status == "completed":
            return payment

        now = datetime.now(UTC)
        payment.status = "completed"
        payment.provider_payment_id = f"cash:{payment.id}"
        payment.verified_at = now
        db.add(payment)
        db.add(
            BookingEvent(
                booking_id=booking.id,
                old_status=booking.status,
                new_status=booking.status,
                actor=f"owner:{actor_id}",
                metadata_={
                    "cash_settled": True,
                    "amount": float(payment.amount),
                    "payment_id": str(payment.id),
                },
            )
        )
        await db.commit()
        await db.refresh(payment)
        return payment


cash_flow_service = CashFlowService()
