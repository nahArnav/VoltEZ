from app.schemas.enums import BookingStatus
from uuid import UUID
from pydantic import BaseModel, Field, model_validator
from typing import Literal, Optional, Dict, Any
from datetime import datetime, timezone



# Shared properties for both incoming requests and API responses.
class BookingBase(BaseModel):
    start_at: datetime
    end_at: datetime

    @model_validator(mode="after")
    def validate_time_rules(self):
        if self.end_at <= self.start_at:
            raise ValueError("end_at must be strictly after start_at")
        return self

# Properties to receive via API on booking creation
class BookingCreate(BookingBase):
    charger_port_id: UUID

    @model_validator(mode="after")
    def validate_new_booking_is_future(self):
        now = datetime.now(timezone.utc)
        if self.start_at < now:
            raise ValueError("Booking start_at cannot be in the past")
        return self


# Properties to receive via API on state transitions
class BookingStatusUpdate(BaseModel):
    status: BookingStatus
    reason: Optional[str] = Field(default=None, description="Optional cancellation or failure reason")


# Properties to return to client
class BookingResponse(BookingBase):
    id: UUID
    user_id: UUID
    charger_port_id: UUID
    status: BookingStatus
    created_at: datetime

    class Config:
        from_attributes = True
