from uuid import UUID
from typing import Any, Dict, Generic, List, Optional, Type, TypeVar, Union
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from database.base_class import Base

# Define Generic Type Variables
ModelType = TypeVar("ModelType", bound=Base)
CreateSchemaType = TypeVar("CreateSchemaType", bound=BaseModel)
UpdateSchemaType = TypeVar("UpdateSchemaType", bound=BaseModel)


class BaseRepository(Generic[ModelType, CreateSchemaType, UpdateSchemaType]):
    def __init__(self, model: Type[ModelType]):
        """
        Base class that can be extended by other repositories.
        Provides basic async CRUD and search operations.
        """
        self.model = model

    async def get(self, db: AsyncSession, id: Any) -> Optional[ModelType]:
        """Fetch a single record by its primary key (id)."""
        model_id = getattr(self.model, "id")
        result = await db.execute(select(self.model).where(model_id == id))
        return result.scalar_one_or_none()

    async def get_multi(self, db: AsyncSession, *, skip: int = 0, limit: int = 100) -> List[ModelType]:
        """Fetch multiple records with pagination."""
        result = await db.execute(select(self.model).offset(skip).limit(limit))
        return list(result.scalars().all())

    async def create(self, db: AsyncSession, *, obj_in: Union[CreateSchemaType, Dict[str, Any]]) -> ModelType:
        """Create a new record in the database using a Pydantic schema or dict."""
        # Convert Pydantic v2 model to a dictionary
        if isinstance(obj_in, dict):
            obj_in_data = obj_in
        else:
            obj_in_data = obj_in.model_dump()
        db_obj = self.model(**obj_in_data)  # type: ignore
        db.add(db_obj)
        await db.flush()
        await db.refresh(db_obj)
        return db_obj

    async def update(
        self, 
        db: AsyncSession, 
        *, 
        db_obj: ModelType, 
        obj_in: Union[UpdateSchemaType, Dict[str, Any]]
    ) -> ModelType:
        """Update an existing record."""
        # Convert current DB object to a dictionary of its columns
        obj_data = {c.name: getattr(db_obj, c.name) for c in db_obj.__table__.columns}
        
        # Convert incoming update payload to dictionary (ignoring unset fields)
        if isinstance(obj_in, dict):
            update_data = obj_in
        else:
            update_data = obj_in.model_dump(exclude_unset=True)
            
        # Apply updates
        for field in obj_data:
            if field in update_data:
                setattr(db_obj, field, update_data[field])
                
        db.add(db_obj)
        await db.flush()
        await db.refresh(db_obj)
        return db_obj

    async def remove(self, db: AsyncSession, *, id: UUID) -> Optional[ModelType]:
        """Delete a record by its ID."""
        obj = await self.get(db=db, id=id)
        if obj:
            await db.delete(obj)
            await db.flush()
        return obj