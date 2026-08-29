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
    # Optional for clients: the API resolves the nearest active zone from the
    # supplied coordinates so mobile onboarding never ships a fixture UUID.
    zone_id: UUID | None = None
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


class BusinessKYCSubmit(BaseModel):
    gstin: str | None = None
    pan_number: str | None = None
    electricity_meter_id: str | None = None
    bank_account_number: str | None = None
    bank_ifsc: str | None = None
    payout_upi_id: str | None = None


class BusinessKYCResponse(BaseModel):
    business_id: UUID
    verification_status: str
    gstin_masked: str | None = None
    pan_masked: str | None = None
    electricity_meter_id: str | None = None
    payout_upi_id: str | None = None
    submitted_at: datetime

