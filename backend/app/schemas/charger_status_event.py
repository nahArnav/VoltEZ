from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, Dict, Any
from datetime import datetime


# Shared properties
class ChargerStatusEventBase(BaseModel):
    status: str = Field(..., description="available, occupied, offline, unknown")
    error_code: Optional[str] = None
    details: Optional[Dict[str, Any]] = None


# Properties received from an API call
class ChargerStatusEventCreate(ChargerStatusEventBase):
    charger_id: UUID


# Properties returned to the client/dashboard
class ChargerStatusEventResponse(ChargerStatusEventBase):
    id: UUID
    charger_id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)