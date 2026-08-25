from app.schemas.enums import BookingStatus
from uuid import UUID
from typing import List, Optional
from datetime import datetime
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.base import BaseRepository
from database.models.booking import Booking
from app.schemas.booking import BookingCreate, BookingStatusUpdate

class RepositoryBooking(BaseRepository[Booking, BookingCreate, BookingStatusUpdate]):
    async def get_by_user(self, db: AsyncSession, user_id: UUID) -> List[Booking]:
        result = await db.execute(select(Booking).where(Booking.user_id == user_id))
        return list(result.scalars().all())

    async def get_active_by_port(self, db: AsyncSession, port_id: UUID, current_time: datetime) -> List[Booking]:
        """Get all upcoming or ongoing bookings for a port."""
        result = await db.execute(
            select(Booking).where(
                and_(
                    Booking.charger_port_id == port_id,
                    Booking.end_at > current_time,
                    Booking.status.in_([
                        BookingStatus.PENDING.value,
                        BookingStatus.HELD.value,
                        BookingStatus.CONFIRMED.value,
                        BookingStatus.CHECKED_IN.value,
                        BookingStatus.CHARGING.value,
                    ])
                )
            )
        )
        return list(result.scalars().all())

booking_repo = RepositoryBooking(Booking)