from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


# Shared properties
class BusinessBase(BaseModel):
    name: str
    category: str = Field(description="e.g., mall, office, apartment")
    address_text: str | None = None


# Properties to receive via API on creation
class BusinessCreate(BusinessBase):
    zone_id: UUID
    # The API receives lat/lng, the backend converts this to PostGIS POINT
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)


# Properties to receive via API on update
class BusinessUpdate(BaseModel):
    name: str | None = None
    category: str | None = None
    address_text: str | None = None
    latitude: float | None = Field(default=None, ge=-90.0, le=90.0)
    longitude: float | None = Field(default=None, ge=-180.0, le=180.0)


# Properties to return to client
class BusinessResponse(BusinessBase):
    id: UUID
    owner_id: UUID
    verification_status: str
    created_at: datetime
    updated_at: datetime

    # We will populate these from the PostGIS location column in the Service layer
    latitude: float | None = None
    longitude: float | None = None

    model_config = ConfigDict(from_attributes=True)
