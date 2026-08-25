from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from app.db.session import get_db
from app.models.user import User, UserRole
from app.schemas.availability_window import AvailabilityWindowCreate, AvailabilityWindowUpdate, AvailabilityWindowResponse
from app.api.v1.deps import get_current_user, require_role
from app.repositories.availability_window import availability_window_repo

router = APIRouter(prefix="/availability", tags=["Availability Windows"])

@router.get("/port/{port_id}", response_model=List[AvailabilityWindowResponse])
async def list_availability_windows(
    port_id: int,
    db: AsyncSession = Depends(get_db)
):
    """List all availability windows for a specific port."""
    windows = await availability_window_repo.get_by_port(db, port_id=port_id)
    return windows

@router.post("/", response_model=AvailabilityWindowResponse, status_code=status.HTTP_201_CREATED)
async def create_availability_window(
    window_in: AvailabilityWindowCreate,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db)
):
    """Create a new availability window. Owners only."""
    window_data = window_in.model_dump()
    window = await availability_window_repo.create(db, obj_in=window_data)
    return window

@router.patch("/{window_id}", response_model=AvailabilityWindowResponse)
async def update_availability_window(
    window_id: int,
    window_in: AvailabilityWindowUpdate,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db)
):
    window = await availability_window_repo.get(db, id=window_id)
    if not window:
        raise HTTPException(status_code=404, detail="Availability window not found")
    
    window = await availability_window_repo.update(db, db_obj=window, obj_in=window_in)
    return window

@router.delete("/{window_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_availability_window(
    window_id: int,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db)
):
    window = await availability_window_repo.get(db, id=window_id)
    if not window:
        raise HTTPException(status_code=404, detail="Availability window not found")
    
    await availability_window_repo.remove(db, id=window_id)
    return None
