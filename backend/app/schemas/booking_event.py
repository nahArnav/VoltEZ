from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


# Shared properties
class BookingEventBase(BaseModel):
    old_status: str | None = Field(
        default=None, description="Previous status; None for creation event"
    )
    new_status: str = Field(..., description="Target status transitioned into")
    actor: str = Field(
        ..., description="Entity triggering transition: 'system', 'user:<id>', 'admin:<id>'"
    )
    metadata_: dict[str, Any] | None = Field(
        default=None, description="Arbitrary transition context, reasons, or payload diffs"
    )


# Properties required when creating an audit event internally
class BookingEventCreate(BookingEventBase):
    booking_id: UUID


# Properties returned to client / admin dashboard
class BookingEventResponse(BookingEventBase):
    id: UUID
    booking_id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)
