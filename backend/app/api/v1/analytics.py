from app.schemas.enums import UserRole
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Dict, Any

from app.api.v1.deps import get_db, get_current_user
from database.models.user import User
from app.repositories.charger import charger_repo
from app.repositories.business import business_repo
from app.ml.adapters import ml_adapter
from pydantic import BaseModel

router = APIRouter(prefix="/analytics", tags=["Analytics & Intelligence"])

class RecommendationResponse(BaseModel):
    charger_id: UUID
    recommended_action: str
    reason_code: str
    expected_demand: float
    suggested_discount_pct: int
    confidence: float

from fastapi import Request

@router.get("/businesses/{business_id}/recommendations", response_model=List[RecommendationResponse])
async def get_business_recommendations(
    business_id: UUID,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Derived Business Intelligence:
    Queries ML demand forecasting to recommend dynamic availability/pricing to owners.
    """
    if current_user.role not in [UserRole.OWNER, UserRole.ADMIN]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
    business = await business_repo.get(db, id=business_id)
    if business is None or (
        current_user.role != UserRole.ADMIN and business.owner_id != current_user.id
    ):
        raise HTTPException(status_code=404, detail="Business not found")
        
    # Get all chargers for this business
    chargers = await charger_repo.get_by_business(db, business_id=business_id)
    if not chargers:
        return []
        
    recommendations = []
    
    demand_model = getattr(request.app.state, "demand_model", None)
    
    for charger in chargers:
        # Call Model A (Demand Forecast)
        forecast = await ml_adapter.predict_demand(
            db, 
            charger_id=charger.id, 
            model=demand_model
        )
        expected = forecast["expected_demand"]
        confidence = forecast["confidence"]
        
        # Derive intelligence logic based on Model 1 target distribution (mean ~0.9, p99 = 5.0)
        if expected < 0.5:
            # Low demand -> suggest discount
            recommendations.append(
                RecommendationResponse(
                    charger_id=charger.id,
                    recommended_action="Create Availability Window",
                    reason_code="BUSINESS_OFF_PEAK",
                    expected_demand=expected,
                    suggested_discount_pct=20,
                    confidence=confidence
                )
            )
        elif expected > 2.0:
            # High demand -> surge pricing or hold slots
            recommendations.append(
                RecommendationResponse(
                    charger_id=charger.id,
                    recommended_action="Enable Peak Pricing",
                    reason_code="HIGH_DEMAND_LOW_SUPPLY",
                    expected_demand=expected,
                    suggested_discount_pct=0,
                    confidence=confidence
                )
            )
            
    return recommendations
