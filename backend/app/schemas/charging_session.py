from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


# Shared properties
class ChargingSessionBase(BaseModel):
    energy_kwh: float | None = Field(
        default=None, ge=0.0, description="Total energy delivered in kWh"
    )
    amount: float | None = Field(
        default=None, ge=0.0, description="Calculated total charge amount in INR"
    )
    status: Literal["reserved", "charging", "completed", "failed"] = "reserved"


# Properties received to initiate a session upon arrival/check-in
class ChargingSessionCreate(BaseModel):
    charger_port_id: UUID
    user_id: UUID
    booking_id: UUID | None = None
    reserved_at: datetime | None = None


# Properties received for session telemetry updates or session completion
class ChargingSessionUpdate(BaseModel):
    started_at: datetime | None = None
    ended_at: datetime | None = None
    energy_kwh: float | None = Field(default=None, ge=0.0)
    amount: float | None = Field(default=None, ge=0.0)
    status: str | None = None


# Properties returned to client
class ChargingSessionResponse(ChargingSessionBase):
    id: UUID
    charger_port_id: UUID
    user_id: UUID
    booking_id: UUID | None = None
    reserved_at: datetime
    started_at: datetime | None = None
    ended_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
