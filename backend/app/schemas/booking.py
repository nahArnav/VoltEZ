from datetime import UTC, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.schemas.enums import BookingStatus


# Shared properties for both incoming requests and API responses.
class BookingBase(BaseModel):
    start_at: datetime
    end_at: datetime


# Properties to receive via API on booking creation
class BookingCreate(BookingBase):
    charger_port_id: UUID

    @model_validator(mode="after")
    def validate_time_rules(self):
        if self.end_at <= self.start_at:
            raise ValueError("end_at must be strictly after start_at")
        now = datetime.now(UTC)
        if self.start_at < now:
            raise ValueError("Booking start_at cannot be in the past")
        return self


# Properties to receive via API on state transitions
class BookingStatusUpdate(BaseModel):
    status: BookingStatus
    reason: str | None = Field(default=None, description="Optional cancellation or failure reason")


# Properties to return to client
class BookingResponse(BookingBase):
    id: UUID
    user_id: UUID
    charger_port_id: UUID
    status: BookingStatus
    estimated_amount: float | None = None
    hold_expires_at: datetime | None = None
    cancelled_at: datetime | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
