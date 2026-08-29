from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr

from app.schemas.enums import UserRole


# Shared properties
class UserBase(BaseModel):
    name: str
    email: EmailStr


# Properties to receive via API on creation
class UserCreate(UserBase):
    password: str
    # Lock down the role to only these two options. Reject anything else.
    role: Literal["driver", "owner"] = "driver"
    phone: str | None = None


# Properties to receive via API on update (PATCH /users/me)
class UserUpdate(BaseModel):
    name: str | None = None
    phone: str | None = None


# Login request
class UserLogin(BaseModel):
    email: EmailStr
    password: str


# Token response
class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


# Refresh token request
class TokenRefresh(BaseModel):
    refresh_token: str


# Properties to return to client (hides password_hash)
class UserResponse(UserBase):
    id: UUID
    role: UserRole
    phone: str | None = None
    verification_status: str
    created_at: datetime

    # This tells Pydantic to read data directly from the SQLAlchemy model
    model_config = ConfigDict(from_attributes=True)


class UserKYCSubmit(BaseModel):
    document_type: Literal["driving_license", "aadhaar", "voter_id", "passport"] = "driving_license"
    document_number: str
    vehicle_rc_number: str | None = None


class UserKYCResponse(BaseModel):
    user_id: UUID
    verification_status: str
    document_type: str
    document_number_masked: str
    vehicle_rc_number: str | None = None
    submitted_at: datetime
    cancellation_strikes: int = 0
    penalty_points: int = 0
    suspended_until: datetime | None = None
