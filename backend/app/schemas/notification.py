from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class NotificationBase(BaseModel):
    type: str = Field(..., description="e.g., booking_confirmed, session_reminder, hold_expiring")
    title: str
    message: str
    data: dict[str, Any] | None = Field(
        default=None, description="Dynamic data for template rendering"
    )
    status: str | None = Field(default="unread", description="unread, read")


class NotificationCreate(NotificationBase):
    user_id: UUID


class NotificationUpdate(BaseModel):
    status: str | None = None
    read_at: datetime | None = None


class NotificationResponse(NotificationBase):
    id: UUID
    user_id: UUID
    read_at: datetime | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
