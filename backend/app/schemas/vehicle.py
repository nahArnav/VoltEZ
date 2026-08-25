from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List
from datetime import datetime


# Shared properties
class VehicleBase(BaseModel):
    make: str = Field(..., examples=["Tata"])
    model: str = Field(..., examples=["Nexon EV"])
    battery_kwh: float = Field(..., gt=0.0, description="Total battery capacity in kWh")
    connector_types: List[str] = Field(..., min_length=1, description="List of supported connectors, e.g. ['CCS2', 'Type2']")
    max_ac_kw: Optional[float] = Field(default=None, gt=0.0, description="Max supported AC charging speed in kW")
    max_dc_kw: Optional[float] = Field(default=None, gt=0.0, description="Max supported DC fast-charging speed in kW")
    estimated_range_km: Optional[float] = Field(default=None, gt=0.0, description="Rated or real-world range in km")


# Properties to receive via API on vehicle registration
class VehicleCreate(VehicleBase):
    pass


# Properties to receive via API on vehicle update
class VehicleUpdate(BaseModel):
    make: Optional[str] = None
    model: Optional[str] = None
    battery_kwh: Optional[float] = Field(default=None, gt=0.0)
    connector_types: Optional[List[str]] = Field(default=None, min_length=1)
    max_ac_kw: Optional[float] = Field(default=None, gt=0.0)
    max_dc_kw: Optional[float] = Field(default=None, gt=0.0)
    estimated_range_km: Optional[float] = Field(default=None, gt=0.0)


# Properties returned to client
class VehicleResponse(VehicleBase):
    id: UUID
    user_id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)