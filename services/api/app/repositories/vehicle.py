from typing import List
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.base import BaseRepository
from app.models.vehicle import Vehicle
from app.schemas.vehicle import VehicleCreate, VehicleUpdate

class RepositoryVehicle(BaseRepository[Vehicle, VehicleCreate, VehicleUpdate]):
    async def get_by_owner(self, db: AsyncSession, driver_id: int) -> List[Vehicle]:
        """Fetch all vehicles registered to a specific driver."""
        result = await db.execute(select(Vehicle).where(Vehicle.driver_id == driver_id))
        return list(result.scalars().all())

vehicle_repo = RepositoryVehicle(Vehicle)