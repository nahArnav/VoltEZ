from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, Dict, Any
from datetime import datetime


# Shared properties
class BookingEventBase(BaseModel):
    old_status: Optional[str] = Field(default=None, description="Previous status; None for creation event")
    new_status: str = Field(..., description="Target status transitioned into")
    actor: str = Field(..., description="Entity triggering transition: 'system', 'user:<id>', 'admin:<id>'")
    metadata_: Optional[Dict[str, Any]] = Field(
        default=None, 
        description="Arbitrary transition context, reasons, or payload diffs"
    )


# Properties required when creating an audit event internally
class BookingEventCreate(BookingEventBase):
    booking_id: int


# Properties returned to client / admin dashboard
class BookingEventResponse(BookingEventBase):
    id: int
    booking_id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)