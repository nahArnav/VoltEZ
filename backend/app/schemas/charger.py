from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict
from typing import Literal, Optional, List
from datetime import datetime
from app.schemas.charger_port import ChargerPortResponse

# Shared properties
class ChargerBase(BaseModel):
    name: str
    charger_type: str
    power_kw: float = Field(..., gt=0.0, description="Total station power capacity in kW")
    status: Literal["available", "unavailable", "maintenance", "offline"] = "available"

# Properties to receive via API on creation
class ChargerCreate(ChargerBase):
    business_id: UUID
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)

# Properties to receive via API on update
class ChargerUpdate(BaseModel):
    name: Optional[str] = None
    charger_type: Optional[str] = None
    power_kw: Optional[float] = Field(default=None, gt=0.0)
    status: Optional[str] = None
    latitude: Optional[float] = Field(default=None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(default=None, ge=-180.0, le=180.0)

# Properties to return to client
class ChargerResponse(ChargerBase):
    id: UUID
    business_id: UUID
    reliability_score: float = Field(default=100.0, ge=0.0, le=100.0)
    created_at: datetime
    updated_at: datetime
    
    # Decoded from PostGIS location column
    latitude: float
    longitude: float

    # Automatically loads the nested ports because of lazy="selectin" in the SQLAlchemy model
    ports: List[ChargerPortResponse] = []

    model_config = ConfigDict(from_attributes=True)