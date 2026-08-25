from typing import List
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.base import BaseRepository
from app.models.availability_window import AvailabilityWindow
from app.schemas.availability_window import AvailabilityWindowCreate, AvailabilityWindowUpdate

class RepositoryAvailabilityWindow(BaseRepository[AvailabilityWindow, AvailabilityWindowCreate, AvailabilityWindowUpdate]):
    async def get_by_port(self, db: AsyncSession, port_id: int) -> List[AvailabilityWindow]:
        """Fetch all availability windows for a specific port."""
        result = await db.execute(select(AvailabilityWindow).where(AvailabilityWindow.port_id == port_id))
        return list(result.scalars().all())

availability_window_repo = RepositoryAvailabilityWindow(AvailabilityWindow)
