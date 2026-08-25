from pydantic import BaseModel, Field
from typing import Literal, Optional, List
from datetime import datetime
from app.schemas.charger_port import ChargerPortResponse

# Shared properties
class ChargerBase(BaseModel):
    name: str
    power_kw: float = Field(..., gt=0.0, description="Total station power capacity in kW")
    access_type: Literal["public", "private", "restricted"] = "public"
    base_price: float = Field(..., ge=0.0, description="Base rate in INR per kWh")
    status: Literal["active", "paused", "inactive"] = "active"
    parking_info: Optional[str] = None
    amenities: Optional[str] = Field(default=None, description="Comma-separated list of amenities")

# Properties to receive via API on creation
class ChargerCreate(ChargerBase):
    business_id: int
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)

# Properties to receive via API on update
class ChargerUpdate(BaseModel):
    name: Optional[str] = None
    power_kw: Optional[float] = Field(default=None, gt=0.0)
    access_type: Optional[str] = None
    base_price: Optional[float] = Field(default=None, ge=0.0)
    status: Optional[str] = None
    parking_info: Optional[str] = None
    amenities: Optional[str] = None
    latitude: Optional[float] = Field(default=None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(default=None, ge=-180.0, le=180.0)

# Properties to return to client
class ChargerResponse(ChargerBase):
    id: int
    business_id: int
    reliability_score: float = Field(..., ge=0.0, le=1.0)
    created_at: datetime
    updated_at: datetime
    
    # Decoded from PostGIS location column
    latitude: float
    longitude: float

    # Automatically loads the nested ports because of lazy="selectin" in the SQLAlchemy model
    ports: List[ChargerPortResponse] = []

    class Config:
        from_attributes = True