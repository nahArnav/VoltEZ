from app.schemas.enums import UserRole
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from app.db.session import get_db
from database.models.user import User
from app.schemas.business import BusinessCreate, BusinessUpdate, BusinessResponse
from app.api.v1.deps import get_current_user, require_role
from app.repositories.business import business_repo

router = APIRouter(prefix="/businesses", tags=["Businesses"])


@router.get("/me", response_model=BusinessResponse)
async def get_my_business(
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    """Return the owner's primary business for the current single-business UI."""
    businesses = await business_repo.get_by_owner_id(db, owner_id=current_user.id)
    if not businesses:
        raise HTTPException(status_code=404, detail="Business not found")
    return businesses[0]

@router.get("/", response_model=List[BusinessResponse])
async def list_businesses(
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db)
):
    """List all businesses for the current owner."""
    # type ignore for Pylance Column[int] false positive
    businesses = await business_repo.get_by_owner_id(db, owner_id=current_user.id)  # type: ignore
    return businesses

@router.post("/", response_model=BusinessResponse, status_code=status.HTTP_201_CREATED)
async def create_business(
    business_in: BusinessCreate,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db)
):
    """Register a new business."""
    business_data = business_in.model_dump()
    
    # Extract lat/lng to convert to PostGIS geometry
    lat = business_data.pop("latitude", None)
    lon = business_data.pop("longitude", None)
    if lat is not None and lon is not None:
        business_data["location"] = f"SRID=4326;POINT({lon} {lat})"
        
    business_data["owner_id"] = current_user.id
    business_data["verification_status"] = "pending"
    
    business = await business_repo.create(db, obj_in=business_data)
    await db.commit()
    await db.refresh(business)
    
    # Attach lat/lng for Pydantic serialization
    setattr(business, "latitude", lat)
    setattr(business, "longitude", lon)
    
    return business

@router.get("/{business_id}", response_model=BusinessResponse)
async def get_business(
    business_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    business = await business_repo.get(db, id=business_id)
    if not business:
        raise HTTPException(status_code=404, detail="Business not found")
    # For now, let anyone view a business, or restrict to owner if needed.
    return business

@router.patch("/{business_id}", response_model=BusinessResponse)
async def update_business(
    business_id: UUID,
    business_in: BusinessUpdate,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db)
):
    business = await business_repo.get(db, id=business_id)
    if not business or business.owner_id != current_user.id:  # type: ignore
        raise HTTPException(status_code=404, detail="Business not found or unauthorized")
    
    update_data = business_in.model_dump(exclude_unset=True)
    lat = update_data.pop("latitude", None)
    lon = update_data.pop("longitude", None)
    if (lat is None) != (lon is None):
        raise HTTPException(
            status_code=422,
            detail="latitude and longitude must be updated together",
        )
    if lat is not None and lon is not None:
        update_data["location"] = f"SRID=4326;POINT({lon} {lat})"

    business = await business_repo.update(db, db_obj=business, obj_in=update_data)
    await db.commit()
    await db.refresh(business)
    if lat is not None:
        setattr(business, "latitude", lat)
        setattr(business, "longitude", lon)
    return business

@router.delete("/{business_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_business(
    business_id: UUID,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db)
):
    business = await business_repo.get(db, id=business_id)
    if not business or business.owner_id != current_user.id:  # type: ignore
        raise HTTPException(status_code=404, detail="Business not found or unauthorized")
    
    await business_repo.remove(db, id=business_id)
    await db.commit()
    return None
