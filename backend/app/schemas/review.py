from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional
from datetime import datetime


# Shared properties
class ReviewBase(BaseModel):
    rating: int = Field(..., ge=1, le=5, description="Rating from 1 to 5")
    comment: Optional[str] = None
    issue_flags: list[str] | None = Field(default=None, max_length=5)


# Properties received from the driver after a session
class ReviewCreate(ReviewBase):
    session_id: UUID
    # user_id will be injected by the AuthService token, not the request payload


# Properties to return to the client (e.g., when viewing a charger's reviews)
class ReviewResponse(ReviewBase):
    id: UUID
    session_id: UUID
    user_id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
