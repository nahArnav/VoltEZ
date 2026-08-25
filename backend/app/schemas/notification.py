from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, Dict, Any
from datetime import datetime


class NotificationBase(BaseModel):
    type: str = Field(..., description="e.g., booking_confirmed, session_reminder, hold_expiring")
    payload: Optional[Dict[str, Any]] = Field(default=None, description="Dynamic data for template rendering")
    status: Optional[str] = Field(default="pending", description="pending, sent, failed, read")
    scheduled_at: Optional[datetime] = None


class NotificationCreate(NotificationBase):
    user_id: UUID


class NotificationUpdate(BaseModel):
    status: Optional[str] = None
    sent_at: Optional[datetime] = None


class NotificationResponse(NotificationBase):
    id: UUID
    user_id: UUID
    sent_at: Optional[datetime] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)