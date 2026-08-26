from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from app.db.session import get_db
from database.models.user import User
from app.schemas.vehicle import VehicleCreate, VehicleUpdate, VehicleResponse
from app.api.v1.deps import get_current_user
from app.repositories.vehicle import vehicle_repo

router = APIRouter(prefix="/vehicles", tags=["Vehicles"])

@router.get("/", response_model=List[VehicleResponse])
async def list_vehicles(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """List all vehicles for the current user."""
    uid = current_user.id
    vehicles = await vehicle_repo.get_by_owner(db, user_id=uid)
    return vehicles

@router.post("/", response_model=VehicleResponse, status_code=status.HTTP_201_CREATED)
async def create_vehicle(
    vehicle_in: VehicleCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Register a new vehicle."""
    try:
        return await vehicle_repo.create_for_owner(
            db,
            user_id=current_user.id,
            obj_in=vehicle_in,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

@router.get("/{vehicle_id}", response_model=VehicleResponse)
async def get_vehicle(
    vehicle_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    vehicle = await vehicle_repo.get(db, id=vehicle_id)
    uid = current_user.id
    if not vehicle or vehicle.user_id != uid:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    return vehicle

@router.patch("/{vehicle_id}", response_model=VehicleResponse)
async def update_vehicle(
    vehicle_id: UUID,
    vehicle_in: VehicleUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    vehicle = await vehicle_repo.get(db, id=vehicle_id)
    uid = current_user.id
    if not vehicle or vehicle.user_id != uid:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    
    try:
        return await vehicle_repo.update_with_connectors(
            db,
            db_obj=vehicle,
            obj_in=vehicle_in,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

@router.delete("/{vehicle_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_vehicle(
    vehicle_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    vehicle = await vehicle_repo.get(db, id=vehicle_id)
    uid = current_user.id
    if not vehicle or vehicle.user_id != uid:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    
    await vehicle_repo.remove(db, id=vehicle_id)
    await db.commit()
    return None
