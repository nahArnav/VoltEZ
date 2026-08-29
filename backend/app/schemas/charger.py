from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.charger_port import ChargerPortResponse


# Shared properties
class ChargerBase(BaseModel):
    name: str
    charger_type: str
    address_text: str | None = None
    power_kw: float = Field(..., gt=0.0, description="Total station power capacity in kW")
    price_per_kwh: float = Field(15.0, gt=0.0, description="INR charged per delivered kWh")
    status: Literal["available", "unavailable", "maintenance", "offline"] = "available"
    access_type: Literal["public", "controlled", "customer_only"] = "public"


# Properties to receive via API on creation
class ChargerCreate(ChargerBase):
    business_id: UUID
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    # Optional first port. Keeping this in the create contract lets the owner
    # register a bookable charger atomically instead of creating an empty
    # station that can never appear in slot search.
    connector_type_id: int | None = Field(default=None, gt=0)
    port_number: int | None = Field(default=None, gt=0)
    port_max_power_kw: float | None = Field(default=None, gt=0.0)


# Properties to receive via API on update
class ChargerUpdate(BaseModel):
    name: str | None = None
    charger_type: str | None = None
    power_kw: float | None = Field(default=None, gt=0.0)
    price_per_kwh: float | None = Field(default=None, gt=0.0)
    status: str | None = None
    access_type: Literal["public", "controlled", "customer_only"] | None = None
    latitude: float | None = Field(default=None, ge=-90.0, le=90.0)
    longitude: float | None = Field(default=None, ge=-180.0, le=180.0)


# Properties to return to client
class ChargerResponse(ChargerBase):
    id: UUID
    business_id: UUID
    reliability_score: float = Field(default=100.0, ge=0.0, le=100.0)
    created_at: datetime
    updated_at: datetime
    address_text: str | None = None

    # Decoded from PostGIS location column
    latitude: float
    longitude: float

    # Automatically loads the nested ports because of lazy="selectin" in the SQLAlchemy model
    ports: list[ChargerPortResponse] = []

    model_config = ConfigDict(from_attributes=True)
