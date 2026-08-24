from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from app.db.session import get_db
from app.models.user import User, UserRole
from app.schemas.business import BusinessCreate, BusinessUpdate, BusinessResponse
from app.api.v1.deps import get_current_user, require_role
from app.repositories.business import business_repo

router = APIRouter(prefix="/businesses", tags=["Businesses"])

@router.get("/", response_model=List[BusinessResponse])
async def list_businesses(
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db)
):
    """List all businesses for the current owner."""
    businesses = await business_repo.get_by_owner_id(db, owner_id=current_user.id)
    return businesses

@router.post("/", response_model=BusinessResponse, status_code=status.HTTP_201_CREATED)
async def create_business(
    business_in: BusinessCreate,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db)
):
    """Register a new business."""
    business_data = business_in.model_dump()
    business_data["owner_id"] = current_user.id
    business_data["verification_status"] = "PENDING"
    business = await business_repo.create(db, obj_in=business_data)
    return business

@router.get("/{business_id}", response_model=BusinessResponse)
async def get_business(
    business_id: int,
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
    business_id: int,
    business_in: BusinessUpdate,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db)
):
    business = await business_repo.get(db, id=business_id)
    if not business or business.owner_id != current_user.id:
        raise HTTPException(status_code=404, detail="Business not found or unauthorized")
    
    business = await business_repo.update(db, db_obj=business, obj_in=business_in)
    return business

@router.delete("/{business_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_business(
    business_id: int,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db)
):
    business = await business_repo.get(db, id=business_id)
    if not business or business.owner_id != current_user.id:
        raise HTTPException(status_code=404, detail="Business not found or unauthorized")
    
    await business_repo.remove(db, id=business_id)
    return None
