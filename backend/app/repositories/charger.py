from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.repositories.base import BaseRepository
from app.schemas.charger import ChargerCreate, ChargerUpdate
from app.schemas.charger_port import ChargerPortCreate, ChargerPortUpdate
from database.models.charger import Charger
from database.models.charger_port import ChargerPort


class RepositoryCharger(BaseRepository[Charger, ChargerCreate, ChargerUpdate]):
    async def get_by_business(self, db: AsyncSession, business_id: UUID) -> list[Charger]:
        """Fetch all chargers belonging to a specific business/location."""
        result = await db.execute(select(Charger).where(Charger.business_id == business_id))
        return list(result.scalars().all())

    async def get_with_ports(self, db: AsyncSession, charger_id: UUID) -> Charger | None:
        """
        Fetch a single charger and eager-load its ports in one query.
        This is highly optimized for when the frontend needs the full station profile.
        """
        result = await db.execute(
            select(Charger).options(selectinload(Charger.ports)).where(Charger.id == charger_id)
        )
        return result.scalar_one_or_none()


class RepositoryChargerPort(BaseRepository[ChargerPort, ChargerPortCreate, ChargerPortUpdate]):
    async def get_by_charger(self, db: AsyncSession, charger_id: UUID) -> list[ChargerPort]:
        """Fetch all ports for a specific charger."""
        result = await db.execute(select(ChargerPort).where(ChargerPort.charger_id == charger_id))
        return list(result.scalars().all())


# Instantiate the repositories
charger_repo = RepositoryCharger(Charger)
charger_port_repo = RepositoryChargerPort(ChargerPort)
