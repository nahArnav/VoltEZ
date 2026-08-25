from app.schemas.enums import ChargerStatus
from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional
from datetime import datetime


# Shared properties
class ChargerStatusEventBase(BaseModel):
    status: str = Field(..., description="available, occupied, offline, unknown")
    source: str = Field(..., description="OWNER, DRIVER_CHECKIN, DRIVER_CHECKOUT, BOOKING_DERIVED, ADMIN, CPO_IOT")
    confidence: float = Field(default=0.5, ge=0.0, le=1.0, description="Trust level of the report, from 0.0 to 1.0")


# Properties received from an API call (e.g., driver taps "Report Broken")
class ChargerStatusEventCreate(ChargerStatusEventBase):
    charger_id: UUID
    port_id: Optional[int] = Field(default=None, description="Optional: specific port ID if known")
    observed_at: Optional[datetime] = Field(
        default=None, 
        description="Time the event was witnessed. Defaults to now if omitted."
    )


# Properties returned to the client/dashboard
class ChargerStatusEventResponse(ChargerStatusEventBase):
    id: UUID
    charger_id: UUID
    port_id: Optional[int] = None
    observed_at: datetime
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)