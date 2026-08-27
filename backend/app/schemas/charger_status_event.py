from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


# Shared properties
class ChargerStatusEventBase(BaseModel):
    status: str = Field(..., description="available, occupied, offline, unknown")
    error_code: str | None = None
    details: dict[str, Any] | None = None


# Properties received from an API call
class ChargerStatusEventCreate(ChargerStatusEventBase):
    charger_id: UUID


# Properties returned to the client/dashboard
class ChargerStatusEventResponse(ChargerStatusEventBase):
    id: UUID
    charger_id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
