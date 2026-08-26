from app.schemas.enums import UserRole
from uuid import UUID
from typing import List
from fastapi import APIRouter, Depends, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.charger import ChargerCreate, ChargerResponse, ChargerUpdate
from app.schemas.charger_port import ChargerPortCreate, ChargerPortResponse, ChargerPortUpdate
from app.services.charger import charger_service
from database.models.user import User
from app.api.v1.deps import require_role, get_current_user
from database.models.charger_search_event import ChargerSearchEvent
from app.repositories.charger import charger_repo, charger_port_repo
from app.repositories.business import business_repo
from fastapi import HTTPException

router = APIRouter(prefix="/chargers", tags=["Chargers"])


async def _require_owned_charger(
    db: AsyncSession,
    charger_id: UUID,
    current_user: User,
):
    charger = await charger_repo.get(db, id=charger_id)
    if not charger:
        raise HTTPException(status_code=404, detail="Charger not found")
    business = await business_repo.get(db, id=charger.business_id)
    if current_user.role != UserRole.ADMIN and (
        business is None or business.owner_id != current_user.id
    ):
        raise HTTPException(status_code=404, detail="Charger not found")
    return charger


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
    business = await business_repo.get(db, id=charger_in.business_id)
    if business is None or (
        current_user.role != UserRole.ADMIN and business.owner_id != current_user.id
    ):
        raise HTTPException(status_code=404, detail="Business not found")
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
    current_user: User = Depends(get_current_user),
):
    """
    Find all chargers within a given radius using PostGIS spatial queries.
    Logs telemetry for ML demand forecasting (Model 1).
    """
    chargers = await charger_service.get_nearby_chargers(
        db=db, latitude=latitude, longitude=longitude, radius_meters=radius_meters
    )
    
    # Telemetry
    search_event = ChargerSearchEvent(
        user_id=current_user.id,
        search_location=f"SRID=4326;POINT({longitude} {latitude})",
        search_radius_km=radius_meters / 1000.0,
        chargers_found=len(chargers)
    )
    db.add(search_event)
    await db.commit()
    
    return chargers


@router.get("/", response_model=List[ChargerResponse])
async def list_chargers(
    business_id: UUID = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    business = await business_repo.get(db, id=business_id)
    if not business:
        raise HTTPException(status_code=404, detail="Business not found")
    if current_user.role != UserRole.ADMIN and business.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized for this business")
    chargers = await charger_repo.get_by_business(db, business_id=business_id)
    return [
        await charger_service.get_charger(db, charger.id)
        for charger in chargers
    ]


@router.get("/{charger_id}", response_model=ChargerResponse)
async def get_charger(
    charger_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    charger = await charger_service.get_charger(db, charger_id)
    if not charger:
        raise HTTPException(status_code=404, detail="Charger not found")
    return charger


@router.patch("/{charger_id}", response_model=ChargerResponse)
async def update_charger(
    charger_id: UUID,
    charger_in: ChargerUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
):
    charger = await _require_owned_charger(db, charger_id, current_user)
    update_data = charger_in.model_dump(exclude_unset=True)
    lat = update_data.pop("latitude", None)
    lon = update_data.pop("longitude", None)
    if (lat is None) != (lon is None):
        raise HTTPException(status_code=422, detail="latitude and longitude must be updated together")
    if lat is not None and lon is not None:
        update_data["location"] = f"SRID=4326;POINT({lon} {lat})"
    await charger_repo.update(db, db_obj=charger, obj_in=update_data)
    await db.commit()
    return await charger_service.get_charger(db, charger_id)


@router.delete("/{charger_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_charger(
    charger_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
):
    await _require_owned_charger(db, charger_id, current_user)
    await charger_repo.remove(db, id=charger_id)
    await db.commit()
    return None


@router.post("/{charger_id}/ports", response_model=ChargerPortResponse, status_code=status.HTTP_201_CREATED)
async def create_charger_port(
    charger_id: UUID,
    port_in: ChargerPortCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
):
    await _require_owned_charger(db, charger_id, current_user)
    port = await charger_port_repo.create(
        db,
        obj_in={"charger_id": charger_id, **port_in.model_dump()},
    )
    await db.commit()
    await db.refresh(port)
    return port


@router.patch("/ports/{port_id}", response_model=ChargerPortResponse)
async def update_charger_port(
    port_id: UUID,
    port_in: ChargerPortUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
):
    port = await charger_port_repo.get(db, id=port_id)
    if not port:
        raise HTTPException(status_code=404, detail="Charger port not found")
    await _require_owned_charger(db, port.charger_id, current_user)
    port = await charger_port_repo.update(db, db_obj=port, obj_in=port_in)
    await db.commit()
    return port


@router.post("/{charger_id}/report-issue", status_code=status.HTTP_204_NO_CONTENT)
async def report_charger_issue(
    charger_id: UUID,
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
