from pydantic import BaseModel, EmailStr
from datetime import datetime
from app.models.user import UserRole

# Shared properties
class UserBase(BaseModel):
    name: str
    email: EmailStr

# Properties to receive via API on creation
class UserCreate(UserBase):
    password: str
    role: UserRole = UserRole.DRIVER

# Properties to return to client (hides password_hash)
class UserResponse(UserBase):
    id: int
    role: UserRole
    verification_status: str
    created_at: datetime

    # This tells Pydantic to read data directly from the SQLAlchemy model
    class Config:
        from_attributes = True