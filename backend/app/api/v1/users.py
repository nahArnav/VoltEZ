from app.schemas.enums import UserRole
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from app.db.session import get_db
from database.models.user import User
from app.schemas.user import UserResponse, UserUpdate
from app.api.v1.deps import get_current_user
from app.repositories.user import user_repo

router = APIRouter(prefix="/users", tags=["Users"])

@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """Get current user profile."""
    return current_user

@router.patch("/me", response_model=UserResponse)
async def update_me(
    user_in: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update current user profile."""
    updated_user = await user_repo.update(db, db_obj=current_user, obj_in=user_in)
    return updated_user
