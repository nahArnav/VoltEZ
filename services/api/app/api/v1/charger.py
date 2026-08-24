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


@router.post("/{charger_id}/report-issue", status_code=status.HTTP_204_NO_CONTENT)
async def report_charger_issue(
    charger_id: int,
    current_user: User = Depends(require_role(UserRole.DRIVER, UserRole.ADMIN, UserRole.OWNER)),
    db: AsyncSession = Depends(get_db),
):
    """
    Allow drivers to report a broken charger. This leverages the No-IoT trust system
    to heavily penalize the charger's reliability score.
    """
    from app.services.trust import trust_service
    from app.repositories.charger import charger_repo
    
    charger = await charger_repo.get(db, id=charger_id)
    if not charger:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Charger not found")
        
    await trust_service.record_event(
        db=db,
        charger_id=charger_id,
        status="offline",
        source="DRIVER_REPORT",
        confidence=0.9
    )
    
    await db.commit()
    return None