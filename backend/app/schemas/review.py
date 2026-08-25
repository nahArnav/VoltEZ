from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List
from datetime import datetime


# Shared properties
class ReviewBase(BaseModel):
    rating: float = Field(..., ge=1.0, le=5.0, description="Rating from 1.0 to 5.0")
    comment: Optional[str] = None
    issue_flags: Optional[List[str]] = Field(
        default=None, 
        description="List of predefined tags e.g., ['charger_broken', 'wrong_connector', 'dirty']"
    )


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