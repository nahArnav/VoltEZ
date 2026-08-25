from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, Dict, Any
from datetime import datetime


class NotificationBase(BaseModel):
    type: str = Field(..., description="e.g., booking_confirmed, session_reminder, hold_expiring")
    title: str
    message: str
    data: Optional[Dict[str, Any]] = Field(default=None, description="Dynamic data for template rendering")
    status: Optional[str] = Field(default="unread", description="unread, read")

class NotificationCreate(NotificationBase):
    user_id: UUID

class NotificationUpdate(BaseModel):
    status: Optional[str] = None
    read_at: Optional[datetime] = None

class NotificationResponse(NotificationBase):
    id: UUID
    user_id: UUID
    read_at: Optional[datetime] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)