from app.schemas.enums import UserRole
from uuid import UUID
from pydantic import BaseModel, EmailStr
from typing import Literal, Optional
from datetime import datetime



# Shared properties
class UserBase(BaseModel):
    name: str
    email: EmailStr


# Properties to receive via API on creation
class UserCreate(UserBase):
    password: str
    # Lock down the role to only these two options. Reject anything else.
    role: Literal["DRIVER", "OWNER"] = "DRIVER" 
    phone: Optional[str] = None

# Properties to receive via API on update (PATCH /users/me)
class UserUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None


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
    phone: Optional[str] = None
    verification_status: str
    created_at: datetime

    # This tells Pydantic to read data directly from the SQLAlchemy model
    class Config:
        from_attributes = True