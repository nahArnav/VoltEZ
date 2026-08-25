from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict
from typing import Literal, Optional
from datetime import datetime


# Shared properties
class ChargingSessionBase(BaseModel):
    energy_kwh: Optional[float] = Field(default=None, ge=0.0, description="Total energy delivered in kWh")
    final_amount: Optional[float] = Field(default=None, ge=0.0, description="Calculated total charge amount in INR")
    status: Literal["checked_in", "charging", "completed", "failed"] = "checked_in"


# Properties received to initiate a session upon arrival/check-in
class ChargingSessionCreate(BaseModel):
    booking_id: UUID
    check_in_at: Optional[datetime] = None


# Properties received for session telemetry updates or session completion
class ChargingSessionUpdate(BaseModel):
    start_at: Optional[datetime] = None
    end_at: Optional[datetime] = None
    energy_kwh: Optional[float] = Field(default=None, ge=0.0)
    final_amount: Optional[float] = Field(default=None, ge=0.0)
    status: Optional[str] = None


# Properties returned to client
class ChargingSessionResponse(ChargingSessionBase):
    id: UUID
    booking_id: UUID
    check_in_at: Optional[datetime] = None
    start_at: Optional[datetime] = None
    end_at: Optional[datetime] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)