from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


# Shared properties
class DemandHistoryBase(BaseModel):
    zone_id: UUID = Field(..., description="Geospatial zone identifier")
    timestamp: datetime
    demand_level: float
    active_sessions: int
    queued_vehicles: int


# Properties for internal background workers logging demand
class DemandHistoryCreate(DemandHistoryBase):
    pass


# Properties returned for ML extraction or admin dashboards
class DemandHistoryResponse(DemandHistoryBase):
    id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
