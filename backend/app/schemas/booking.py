from app.schemas.enums import BookingStatus
from uuid import UUID
from pydantic import BaseModel, Field, model_validator
from typing import Literal, Optional, Dict, Any
from datetime import datetime, timezone



# Shared properties
class BookingBase(BaseModel):
    start_at: datetime
    end_at: datetime

    @model_validator(mode="after")
    def validate_time_rules(self):
        # Rule 1: End must be after start
        if self.end_at <= self.start_at:
            raise ValueError("end_at must be strictly after start_at")
        
        # Rule 2: Booking must be in the future (adding a small buffer for server delay)
        now = datetime.now(timezone.utc)
        if self.start_at < now:
            raise ValueError("Booking start_at cannot be in the past")
            
        return self

# Properties to receive via API on booking creation
class BookingCreate(BookingBase):
    charger_port_id: UUID
    vehicle_id: Optional[int] = None
    idempotency_key: Optional[str] = Field(
        default=None, 
        description="Client-generated UUID to prevent duplicate booking submissions"
    )


# Properties to receive via API on state transitions
class BookingStatusUpdate(BaseModel):
    status: BookingStatus
    reason: Optional[str] = Field(default=None, description="Optional cancellation or failure reason")


# Properties to return to client
class BookingResponse(BookingBase):
    id: UUID
    user_id: UUID
    vehicle_id: Optional[int] = None
    charger_port_id: UUID
    status: BookingStatus
    hold_expires_at: Optional[datetime] = None
    quote_snapshot: Optional[Dict[str, Any]] = None
    idempotency_key: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True