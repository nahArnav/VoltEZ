from pydantic import BaseModel, Field, model_validator
from typing import Optional
from datetime import datetime


# Shared properties
class AvailabilityWindowBase(BaseModel):
    start_at: datetime
    end_at: datetime
    source: Optional[str] = Field(default="owner", description="owner, ai_recommendation, admin")
    price_override: Optional[float] = Field(default=None, ge=0.0, description="Overrides charger base price if set")
    status: Optional[str] = Field(default="active", description="active, paused, cancelled")
    is_recurring: Optional[bool] = False
    recurrence_rule: Optional[str] = Field(default=None, description="e.g. RRULE:FREQ=WEEKLY;BYDAY=TU,TH")

    @model_validator(mode="after")
    def validate_time_range(self):
        if self.end_at <= self.start_at:
            raise ValueError("end_at must be strictly after start_at")
        return self


# Properties to receive via API on creation
class AvailabilityWindowCreate(AvailabilityWindowBase):
    port_id: int


# Properties to receive via API on update
class AvailabilityWindowUpdate(BaseModel):
    start_at: Optional[datetime] = None
    end_at: Optional[datetime] = None
    source: Optional[str] = None
    price_override: Optional[float] = Field(default=None, ge=0.0)
    status: Optional[str] = None
    is_recurring: Optional[bool] = None
    recurrence_rule: Optional[str] = None

    @model_validator(mode="after")
    def validate_time_range_update(self):
        if self.start_at and self.end_at and self.end_at <= self.start_at:
            raise ValueError("end_at must be strictly after start_at")
        return self


# Properties to return to client
class AvailabilityWindowResponse(AvailabilityWindowBase):
    id: int
    port_id: int
    created_at: datetime

    class Config:
        from_attributes = True