from uuid import UUID
from typing import List
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.base import BaseRepository
from database.models.charger_availability import ChargerAvailability
from app.schemas.availability_window import AvailabilityWindowCreate, AvailabilityWindowUpdate

class RepositoryAvailabilityWindow(BaseRepository[ChargerAvailability, AvailabilityWindowCreate, AvailabilityWindowUpdate]):
    async def get_by_port(self, db: AsyncSession, charger_port_id: UUID) -> List[ChargerAvailability]:
        """Fetch all availability windows for a specific port."""
        result = await db.execute(select(ChargerAvailability).where(ChargerAvailability.charger_port_id == charger_port_id))
        return list(result.scalars().all())

availability_window_repo = RepositoryAvailabilityWindow(ChargerAvailability)
