from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional
from datetime import datetime


# Shared properties
class MLPredictionBase(BaseModel):
    entity_id: str = Field(..., description="Target ID (e.g., charger_123, zone_abc)")
    model_name: str = Field(..., description="e.g., demand_forecast, wait_prediction")
    model_version: str = Field(..., description="e.g., v1.2.0")
    prediction_type: str = Field(..., description="e.g., demand, wait_minutes, congestion_level")
    value: float = Field(..., description="The predicted numerical value")
    confidence: Optional[float] = Field(default=None, ge=0.0, le=1.0, description="Model confidence score")
    generated_at: Optional[datetime] = Field(
        default=None, 
        description="When the prediction applies/was generated. Defaults to now."
    )


# Properties for internal ML worker insertion
class MLPredictionCreate(MLPredictionBase):
    pass


# Properties returned to the client or analytics dashboard
class MLPredictionResponse(MLPredictionBase):
    id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)