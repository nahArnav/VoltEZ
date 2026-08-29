from datetime import UTC, date, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.repositories.availability_window import availability_window_repo
from app.repositories.booking import booking_repo
from app.services.pricing import dynamic_rate_from_signals
from database.models.business import Business
from database.models.charger import Charger
from database.models.charger_port import ChargerPort


class AvailabilityService:
    slot_minutes = 60

    @staticmethod
    async def _timezone_for_port(db: AsyncSession, port_id: UUID) -> ZoneInfo:
        result = await db.execute(
            select(Business.timezone)
            .select_from(ChargerPort)
            .join(Charger, Charger.id == ChargerPort.charger_id)
            .join(Business, Business.id == Charger.business_id)
            .where(ChargerPort.id == port_id)
        )
        timezone_name = result.scalar_one_or_none() or "Asia/Kolkata"
        try:
            return ZoneInfo(timezone_name)
        except ZoneInfoNotFoundError:
            return ZoneInfo("Asia/Kolkata")

    async def is_slot_bookable(
        self,
        db: AsyncSession,
        port_id: UUID,
        start_at: datetime,
        end_at: datetime,
    ) -> bool:
        """Apply the owner's weekly schedule in the business's local timezone."""
        local_zone = await self._timezone_for_port(db, port_id)
        local_start = start_at.astimezone(local_zone)
        local_end = end_at.astimezone(local_zone)
        if local_start.date() != local_end.date():
            return False

        windows = await availability_window_repo.get_by_port(db, charger_port_id=port_id)
        same_day = [window for window in windows if window.day_of_week == local_start.weekday()]
        positive = [window for window in same_day if not window.is_unavailable]
        blocked = [window for window in same_day if window.is_unavailable]

        is_approved = any(
            window.start_local_time <= local_start.time()
            and local_end.time() <= window.end_local_time
            for window in positive
        )
        is_blocked = any(
            local_start.time() < window.end_local_time
            and local_end.time() > window.start_local_time
            for window in blocked
        )
        return is_approved and not is_blocked

    async def list_open_slots(
        self,
        db: AsyncSession,
        port_id: UUID,
        local_date: date,
    ) -> list[dict]:
        local_zone = await self._timezone_for_port(db, port_id)
        windows = await availability_window_repo.get_by_port(db, charger_port_id=port_id)
        same_day = [window for window in windows if window.day_of_week == local_date.weekday()]
        positive = [window for window in same_day if not window.is_unavailable]
        blocked = [window for window in same_day if window.is_unavailable]
        now = datetime.now(UTC)
        bookings = await booking_repo.get_active_by_port(db, port_id=port_id, current_time=now)

        active_port_count = await db.scalar(
            select(func.count(ChargerPort.id)).where(
                ChargerPort.charger_id
                == (
                    select(ChargerPort.charger_id)
                    .where(ChargerPort.id == port_id)
                    .scalar_subquery()
                ),
                ChargerPort.is_active.is_(True),
            )
        )
        occupancy_pressure = min(
            len(bookings) / max(int(active_port_count or 1), 1),
            1.0,
        )

        price_result = await db.execute(
            select(Charger.price_per_kwh)
            .select_from(ChargerPort)
            .join(Charger, Charger.id == ChargerPort.charger_id)
            .where(ChargerPort.id == port_id)
        )
        price_per_kwh = float(
            price_result.scalar_one_or_none() or settings.DEFAULT_PRICE_PER_KWH_INR
        )

        slots: dict[tuple[datetime, datetime], dict] = {}
        for window in positive:
            cursor = datetime.combine(local_date, window.start_local_time, tzinfo=local_zone)
            window_end = datetime.combine(local_date, window.end_local_time, tzinfo=local_zone)
            while cursor + timedelta(minutes=self.slot_minutes) <= window_end:
                slot_end = cursor + timedelta(minutes=self.slot_minutes)
                start_utc = cursor.astimezone(UTC)
                end_utc = slot_end.astimezone(UTC)
                blocked_by_owner = any(
                    cursor.time() < item.end_local_time and slot_end.time() > item.start_local_time
                    for item in blocked
                )
                overlaps_booking = any(
                    start_utc < booking.end_at and end_utc > booking.start_at
                    for booking in bookings
                )
                if start_utc > now and not blocked_by_owner and not overlaps_booking:
                    quote = dynamic_rate_from_signals(
                        base_rate=price_per_kwh,
                        expected_demand=float(len(bookings)),
                        probability_unavailable=occupancy_pressure,
                        active_ports=max(int(active_port_count or 1), 1),
                        target_time=start_utc,
                    )
                    slots[(start_utc, end_utc)] = {
                        "charger_port_id": port_id,
                        "start_at": start_utc,
                        "end_at": end_utc,
                        "price_per_kwh": quote.effective_rate,
                    }
                cursor = slot_end

        return [slots[key] for key in sorted(slots)]


availability_service = AvailabilityService()
