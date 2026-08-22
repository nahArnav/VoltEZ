from typing import List, Optional
from datetime import datetime
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.base import BaseRepository
from app.models.booking import Booking
from app.models.availability_window import AvailabilityWindow
from app.schemas.booking import BookingCreate, BookingStatusUpdate
from app.schemas.availability_window import AvailabilityWindowCreate, AvailabilityWindowUpdate

class RepositoryBooking(BaseRepository[Booking, BookingCreate, BookingStatusUpdate]):
    async def get_by_user(self, db: AsyncSession, user_id: int) -> List[Booking]:
        result = await db.execute(select(Booking).where(Booking.user_id == user_id))
        return list(result.scalars().all())

    async def get_active_by_port(self, db: AsyncSession, port_id: int, current_time: datetime) -> List[Booking]:
        """Get all upcoming or ongoing bookings for a port."""
        result = await db.execute(
            select(Booking).where(
                and_(
                    Booking.port_id == port_id,
                    Booking.end_at > current_time,
                    Booking.status.in_(["pending", "confirmed", "active"])
                )
            )
        )
        return list(result.scalars().all())

class RepositoryAvailabilityWindow(BaseRepository[AvailabilityWindow, AvailabilityWindowCreate, AvailabilityWindowUpdate]):
    async def get_by_port(self, db: AsyncSession, port_id: int) -> List[AvailabilityWindow]:
        result = await db.execute(select(AvailabilityWindow).where(AvailabilityWindow.port_id == port_id))
        return list(result.scalars().all())

booking_repo = RepositoryBooking(Booking)
window_repo = RepositoryAvailabilityWindow(AvailabilityWindow)