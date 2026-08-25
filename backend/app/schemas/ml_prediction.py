from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, Dict, Any
from datetime import datetime


# Shared properties
class MLPredictionBase(BaseModel):
    model_version: str = Field(..., description="e.g., v1.2.0")
    target_id: UUID
    target_type: str = Field(..., description="e.g., charger, zone")
    prediction_type: str = Field(..., description="e.g., demand, wait_minutes, congestion_level")
    predicted_value: float = Field(..., description="The predicted numerical value")
    confidence_score: float = Field(..., ge=0.0, le=1.0, description="Model confidence score")
    features_used: Optional[Dict[str, Any]] = None


# Properties for internal ML worker insertion
class MLPredictionCreate(MLPredictionBase):
    pass


# Properties returned to the client or analytics dashboard
class MLPredictionResponse(MLPredictionBase):
    id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)