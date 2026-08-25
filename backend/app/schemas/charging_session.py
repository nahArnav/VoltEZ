from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict
from typing import Literal, Optional
from datetime import datetime

# Shared properties
class ChargingSessionBase(BaseModel):
    energy_kwh: Optional[float] = Field(default=None, ge=0.0, description="Total energy delivered in kWh")
    amount: Optional[float] = Field(default=None, ge=0.0, description="Calculated total charge amount in INR")
    status: Literal["reserved", "charging", "completed", "failed"] = "reserved"

# Properties received to initiate a session upon arrival/check-in
class ChargingSessionCreate(BaseModel):
    charger_port_id: UUID
    user_id: UUID
    booking_id: Optional[UUID] = None
    reserved_at: Optional[datetime] = None

# Properties received for session telemetry updates or session completion
class ChargingSessionUpdate(BaseModel):
    started_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None
    energy_kwh: Optional[float] = Field(default=None, ge=0.0)
    amount: Optional[float] = Field(default=None, ge=0.0)
    status: Optional[str] = None

# Properties returned to client
class ChargingSessionResponse(ChargingSessionBase):
    id: UUID
    charger_port_id: UUID
    user_id: UUID
    booking_id: Optional[UUID] = None
    reserved_at: datetime
    started_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)