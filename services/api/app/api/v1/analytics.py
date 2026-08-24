from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Dict, Any

from app.api.v1.deps import get_db, get_current_user
from app.models.user import User, UserRole
from app.repositories.charger import charger_repo
from app.ml.adapters import ml_adapter
from pydantic import BaseModel

router = APIRouter(prefix="/analytics", tags=["Analytics & Intelligence"])

class RecommendationResponse(BaseModel):
    charger_id: int
    recommended_action: str
    reason_code: str
    expected_demand: float
    suggested_discount_pct: int
    confidence: float

@router.get("/businesses/{business_id}/recommendations", response_model=List[RecommendationResponse])
async def get_business_recommendations(
    business_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Derived Business Intelligence:
    Queries ML demand forecasting to recommend dynamic availability/pricing to owners.
    """
    if current_user.role not in [UserRole.OWNER.value, UserRole.ADMIN.value]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
        
    # Get all chargers for this business
    chargers = await charger_repo.get_by_business(db, business_id=business_id)
    if not chargers:
        return []
        
    recommendations = []
    
    for charger in chargers:
        charger_id_int = int(charger.id)  # type: ignore
        
        # Call Model A (Demand Forecast)
        forecast = await ml_adapter.predict_demand(db, charger_id=charger_id_int)
        expected = forecast["expected_demand"]
        confidence = forecast["confidence"]
        
        # Derive intelligence logic
        if expected < 2.0:
            # Low demand -> suggest discount
            recommendations.append(
                RecommendationResponse(
                    charger_id=charger_id_int,
                    recommended_action="Create Availability Window",
                    reason_code="BUSINESS_OFF_PEAK",
                    expected_demand=expected,
                    suggested_discount_pct=20,
                    confidence=confidence
                )
            )
        elif expected > 4.0:
            # High demand -> surge pricing or hold slots
            recommendations.append(
                RecommendationResponse(
                    charger_id=charger_id_int,
                    recommended_action="Enable Peak Pricing",
                    reason_code="HIGH_DEMAND_LOW_SUPPLY",
                    expected_demand=expected,
                    suggested_discount_pct=0,
                    confidence=confidence
                )
            )
            
    return recommendations
