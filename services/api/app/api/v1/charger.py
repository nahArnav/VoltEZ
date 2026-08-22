from typing import List
from fastapi import APIRouter, Depends, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.charger import ChargerCreate, ChargerResponse
from app.services.charger import charger_service
from app.models.user import User, UserRole
from app.api.v1.deps import require_role

router = APIRouter(prefix="/chargers", tags=["Chargers"])


@router.post("/", response_model=ChargerResponse, status_code=status.HTTP_201_CREATED)
async def create_charger(
    charger_in: ChargerCreate,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    """
    Create a new EV charger location.
    Requires OWNER or ADMIN role.
    """
    charger = await charger_service.create_charger(
        db=db, business_id=charger_in.business_id, charger_in=charger_in
    )
    return charger


@router.get("/nearby", response_model=List[ChargerResponse])
async def get_nearby_chargers(
    latitude: float = Query(..., description="Driver's current latitude", ge=-90.0, le=90.0),
    longitude: float = Query(..., description="Driver's current longitude", ge=-180.0, le=180.0),
    radius_meters: int = Query(5000, description="Search radius in meters", gt=0),
    db: AsyncSession = Depends(get_db),
):
    """
    Find all chargers within a given radius using PostGIS spatial queries.
    Public endpoint — no auth required.
    """
    chargers = await charger_service.get_nearby_chargers(
        db=db, latitude=latitude, longitude=longitude, radius_meters=radius_meters
    )
    return chargers