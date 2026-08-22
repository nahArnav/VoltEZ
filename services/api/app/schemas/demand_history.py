from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, Dict, Any
from datetime import datetime


# Shared properties
class DemandHistoryBase(BaseModel):
    zone_id: str = Field(..., description="Geospatial zone or charger cluster identifier")
    time_bucket: datetime = Field(..., description="Start of the 30/60-minute bucket")
    demand_count: Optional[int] = Field(default=0, ge=0, description="Number of bookings/arrivals in this bucket")
    occupancy: Optional[float] = Field(default=None, ge=0.0, le=1.0, description="Fraction of ports occupied, 0.0-1.0")
    contextual_features: Optional[Dict[str, Any]] = Field(
        default=None, 
        description="JSON payload for ML features like weather, holidays, or events"
    )


# Properties for internal background workers logging demand
class DemandHistoryCreate(DemandHistoryBase):
    pass


# Properties returned for ML extraction or admin dashboards
class DemandHistoryResponse(DemandHistoryBase):
    id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)