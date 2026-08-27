from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.base import BaseRepository
from app.schemas.business import BusinessCreate, BusinessUpdate
from database.models.business import Business


class RepositoryBusiness(BaseRepository[Business, BusinessCreate, BusinessUpdate]):
    async def get_by_owner_id(self, db: AsyncSession, owner_id: UUID) -> list[Business]:
        """Fetch all businesses/locations managed by a specific owner."""
        result = await db.execute(select(Business).where(Business.owner_id == owner_id))
        return list(result.scalars().all())


business_repo = RepositoryBusiness(Business)
