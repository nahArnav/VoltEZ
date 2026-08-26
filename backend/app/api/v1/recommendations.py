from app.schemas.enums import UserRole
from uuid import UUID
from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from database.models.user import User
from app.api.v1.deps import get_current_user, require_role
from app.schemas.recommendation import RecommendationRequest, RecommendationResponse
from app.services.recommendation import recommendation_service

router = APIRouter(prefix="/recommendations", tags=["Recommendations"])

@router.post("/", response_model=RecommendationResponse)
async def get_recommendations(
    request: Request,
    request_data: RecommendationRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get charging route recommendations based on battery SoC, vehicle, and route.
    """
    return await recommendation_service.get_recommendations(
        db,
        request_data,
        user_id=current_user.id,
        availability_model=getattr(request.app.state, "availability_model", None),
    )

@router.get("/business/{business_id}")
async def get_business_recommendations(
    business_id: UUID,
    current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN)),
    db: AsyncSession = Depends(get_db)
):
    """
    Get off-peak pricing and availability recommendations for a business.
    Placeholder until the ML integration is ready.
    """
    return {
        "status": "success",
        "message": "Business intelligence engine is under construction.",
        "data": []
    }
