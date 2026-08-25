from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from app.db.session import get_db
from app.models.user import User, UserRole
from app.schemas.vehicle import VehicleCreate, VehicleUpdate, VehicleResponse
from app.api.v1.deps import get_current_user, require_role
from app.repositories.vehicle import vehicle_repo

router = APIRouter(prefix="/vehicles", tags=["Vehicles"])

@router.get("/", response_model=List[VehicleResponse])
async def list_vehicles(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """List all vehicles for the current user."""
    vehicles = await vehicle_repo.get_by_owner(db, user_id=current_user.id)
    return vehicles

@router.post("/", response_model=VehicleResponse, status_code=status.HTTP_201_CREATED)
async def create_vehicle(
    vehicle_in: VehicleCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Register a new vehicle."""
    vehicle_data = vehicle_in.model_dump()
    vehicle_data["user_id"] = current_user.id
    vehicle = await vehicle_repo.create(db, obj_in=vehicle_data)
    return vehicle

@router.get("/{vehicle_id}", response_model=VehicleResponse)
async def get_vehicle(
    vehicle_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    vehicle = await vehicle_repo.get(db, id=vehicle_id)
    if not vehicle or vehicle.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    return vehicle

@router.patch("/{vehicle_id}", response_model=VehicleResponse)
async def update_vehicle(
    vehicle_id: int,
    vehicle_in: VehicleUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    vehicle = await vehicle_repo.get(db, id=vehicle_id)
    if not vehicle or vehicle.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    
    vehicle = await vehicle_repo.update(db, db_obj=vehicle, obj_in=vehicle_in)
    return vehicle

@router.delete("/{vehicle_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_vehicle(
    vehicle_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    vehicle = await vehicle_repo.get(db, id=vehicle_id)
    if not vehicle or vehicle.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    
    await vehicle_repo.remove(db, id=vehicle_id)
    return None
