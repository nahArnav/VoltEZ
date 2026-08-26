from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict, model_validator
from typing import Optional
from datetime import datetime, time

# Shared properties
class AvailabilityWindowBase(BaseModel):
    day_of_week: int = Field(..., ge=0, le=6, description="0=Monday, 6=Sunday")
    start_local_time: time
    end_local_time: time
    is_unavailable: bool = False

    @model_validator(mode="after")
    def validate_time_range(self):
        if self.end_local_time <= self.start_local_time:
            raise ValueError("end_local_time must be strictly after start_local_time")
        return self

# Properties to receive via API on creation
class AvailabilityWindowCreate(AvailabilityWindowBase):
    charger_port_id: UUID

# Properties to receive via API on update
class AvailabilityWindowUpdate(BaseModel):
    day_of_week: Optional[int] = Field(default=None, ge=0, le=6)
    start_local_time: Optional[time] = None
    end_local_time: Optional[time] = None
    is_unavailable: Optional[bool] = None

    @model_validator(mode="after")
    def validate_time_range_update(self):
        if self.start_local_time and self.end_local_time and self.end_local_time <= self.start_local_time:
            raise ValueError("end_local_time must be strictly after start_local_time")
        return self

# Properties to return to client
class AvailabilityWindowResponse(AvailabilityWindowBase):
    id: UUID
    charger_port_id: UUID

    model_config = ConfigDict(from_attributes=True)


class AvailabilitySlotResponse(BaseModel):
    charger_port_id: UUID
    start_at: datetime
    end_at: datetime
    price_per_kwh: float = Field(..., gt=0)
