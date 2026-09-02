from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_current_user, require_role
from app.db.session import get_db
from app.repositories.availability_window import availability_window_repo
from app.repositories.business import business_repo
from app.repositories.charger import charger_port_repo, charger_repo
from app.schemas.availability_window import (
    AvailabilitySlotResponse,
    AvailabilityWindowCreate,
    AvailabilityWindowResponse,
    AvailabilityWindowUpdate,
)
from app.schemas.enums import UserRole
from app.services.availability import availability_service
from app.ml.adapters import ml_adapter
from database.models.user import User

router = APIRouter(prefix="/availability", tags=["Availability Windows"])


async def _require_owned_port(
    db: AsyncSession,
    port_id: UUID,
    current_user: User,
):
    port = await charger_port_repo.get(db, id=port_id)
    if not port:
        raise HTTPException(status_code=404, detail="Charger port not found")
    charger = await charger_repo.get(db, id=port.charger_id)
    business = await business_repo.get(db, id=charger.business_id) if charger else None
    if current_user.role != UserRole.ADMIN and (
        business is None or business.owner_id != current_user.id
    ):
        raise HTTPException(status_code=404, detail="Charger port not found")
    return port


@router.get("/port/{port_id}", response_model=list[AvailabilityWindowResponse])
async def list_availability_windows(port_id: UUID, db: AsyncSession = Depends(get_db)):
    """List all availability windows for a specific port."""
    windows = await availability_window_repo.get_by_port(db, charger_port_id=port_id)
    return windows


@router.get("/port/{port_id}/slots", response_model=list[AvailabilitySlotResponse])
async def list_open_slots(
    port_id: UUID,
    day: date,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return owner-approved one-hour slots after removing active bookings."""
    del current_user
    port = await charger_port_repo.get(db, id=port_id)
    if port is None or not port.is_active:
        raise HTTPException(status_code=404, detail="Active charger port not found")
    return await availability_service.list_open_slots(db, port_id, day)


@router.post("/", response_model=AvailabilityWindowResponse, status_code=status.HTTP_201_CREATED)
async def create_availability_window(
    window_in: AvailabilityWindowCreate,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    """Create a new availability window. Owners only."""
    await _require_owned_port(db, window_in.charger_port_id, current_user)
    window_data = window_in.model_dump()
    window = await availability_window_repo.create(db, obj_in=window_data)
    await db.commit()
    await db.refresh(window)
    return window


@router.patch("/{window_id}", response_model=AvailabilityWindowResponse)
async def update_availability_window(
    window_id: UUID,
    window_in: AvailabilityWindowUpdate,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    window = await availability_window_repo.get(db, id=window_id)
    if not window:
        raise HTTPException(status_code=404, detail="Availability window not found")
    await _require_owned_port(db, window.charger_port_id, current_user)
    window = await availability_window_repo.update(db, db_obj=window, obj_in=window_in)
    await db.commit()
    await db.refresh(window)
    return window


@router.delete("/{window_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_availability_window(
    window_id: UUID,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    window = await availability_window_repo.get(db, id=window_id)
    if not window:
        raise HTTPException(status_code=404, detail="Availability window not found")
    await _require_owned_port(db, window.charger_port_id, current_user)
    await availability_window_repo.remove(db, id=window_id)
    await db.commit()
    return None
