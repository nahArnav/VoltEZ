from uuid import UUID
from typing import List
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.base import BaseRepository
from database.models.vehicle import Vehicle
from database.models.connector import ConnectorType
from app.schemas.vehicle import VehicleCreate, VehicleUpdate

class RepositoryVehicle(BaseRepository[Vehicle, VehicleCreate, VehicleUpdate]):
    async def get_by_owner(self, db: AsyncSession, user_id: UUID) -> List[Vehicle]:
        """Fetch all vehicles registered to a specific driver."""
        result = await db.execute(select(Vehicle).where(Vehicle.user_id == user_id))
        return list(result.scalars().all())

    async def _resolve_connectors(
        self, db: AsyncSession, connector_type_ids: list[int]
    ) -> list[ConnectorType]:
        result = await db.execute(
            select(ConnectorType).where(ConnectorType.id.in_(connector_type_ids))
        )
        connectors = list(result.scalars().all())
        if len(connectors) != len(set(connector_type_ids)):
            raise ValueError("One or more connector_type_ids do not exist")
        return connectors

    async def create_for_owner(
        self,
        db: AsyncSession,
        *,
        user_id: UUID,
        obj_in: VehicleCreate,
    ) -> Vehicle:
        data = obj_in.model_dump()
        connector_type_ids = data.pop("connector_type_ids")
        vehicle = Vehicle(user_id=user_id, **data)
        vehicle.connector_types = await self._resolve_connectors(db, connector_type_ids)
        db.add(vehicle)
        await db.commit()
        await db.refresh(vehicle, attribute_names=["connector_types"])
        return vehicle

    async def update_with_connectors(
        self,
        db: AsyncSession,
        *,
        db_obj: Vehicle,
        obj_in: VehicleUpdate,
    ) -> Vehicle:
        data = obj_in.model_dump(exclude_unset=True)
        connector_type_ids = data.pop("connector_type_ids", None)
        for field, value in data.items():
            setattr(db_obj, field, value)
        if connector_type_ids is not None:
            db_obj.connector_types = await self._resolve_connectors(db, connector_type_ids)
        db.add(db_obj)
        await db.commit()
        await db.refresh(db_obj, attribute_names=["connector_types"])
        return db_obj

vehicle_repo = RepositoryVehicle(Vehicle)
