from datetime import UTC, datetime, timedelta
from uuid import UUID

from arq.connections import RedisSettings
from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.logging import get_logger
from app.db.session import AsyncSessionLocal
from app.schemas.enums import BookingStatus
from database.models.booking import Booking
from database.models.booking_event import BookingEvent

logger = get_logger("worker")
_HELD_STATUSES = (BookingStatus.PENDING.value, BookingStatus.HELD.value)


def _mark_booking_expired(db: AsyncSession, booking: Booking, *, actor: str) -> bool:
    """Expire a hold once and append the same auditable state transition."""
    if booking.status not in _HELD_STATUSES:
        return False

    old_status = booking.status
    booking.status = BookingStatus.EXPIRED.value
    db.add(booking)
    db.add(
        BookingEvent(
            booking_id=booking.id,
            old_status=old_status,
            new_status=BookingStatus.EXPIRED.value,
            actor=actor,
        )
    )
    return True


async def expire_unpaid_booking(ctx: dict, booking_id: str) -> None:
    """Expire a single unpaid booking after its ten-minute ARQ delay."""
    del ctx
    try:
        parsed_id = UUID(booking_id)
    except ValueError:
        logger.warning("Ignoring an expiry job with an invalid booking identifier")
        return

    async with AsyncSessionLocal() as db:
        booking = await db.get(Booking, parsed_id)
        if booking is None:
            logger.info("Expiry job referenced a booking that no longer exists")
            return
        if _mark_booking_expired(db, booking, actor="system:hold-expiry-worker"):
            await db.commit()
            logger.info("Expired one unpaid booking hold")


async def reconcile_expired_booking_holds() -> int:
    """Recover expired holds whose delayed Redis job was lost or never consumed.

    This makes switching Redis providers safe: the database remains the source
    of truth, and starting a worker repairs stale holds before processing new
    queue entries.
    """
    now = datetime.now(UTC)
    legacy_cutoff = now - timedelta(minutes=10)
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(Booking).where(
                Booking.status.in_(_HELD_STATUSES),
                or_(
                    Booking.hold_expires_at <= now,
                    and_(
                        Booking.hold_expires_at.is_(None),
                        Booking.created_at <= legacy_cutoff,
                    ),
                ),
            )
        )
        repaired = sum(
            _mark_booking_expired(db, booking, actor="system:worker-startup-reconciliation")
            for booking in result.scalars().all()
        )
        if repaired:
            await db.commit()
            logger.info("Reconciled %d expired booking holds at worker startup", repaired)
        return repaired


class WorkerSettings:
    functions = [expire_unpaid_booking]
    redis_settings = RedisSettings.from_dsn(settings.REDIS_URL)
    health_check_interval = 30
    health_check_key = settings.WORKER_HEALTH_CHECK_KEY
    max_jobs = 5

    @staticmethod
    async def on_startup(ctx: dict) -> None:
        del ctx
        repaired = await reconcile_expired_booking_holds()
        logger.info("VoltEZ worker ready; startup_reconciled=%d", repaired)

    @staticmethod
    async def on_shutdown(ctx: dict) -> None:
        del ctx
        logger.info("VoltEZ worker shutting down")
