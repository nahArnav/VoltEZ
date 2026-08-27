from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


# Shared properties
class VehicleBase(BaseModel):
    make: str = Field(..., examples=["Tata"])
    model: str = Field(..., examples=["Nexon EV"])
    vehicle_class: str
    battery_kwh: float = Field(..., gt=0.0, description="Total battery capacity in kWh")
    connector_type_ids: list[int] = Field(
        ..., min_length=1, description="List of supported connector type IDs"
    )
    max_ac_kw: float | None = Field(
        default=None, gt=0.0, description="Max supported AC charging speed in kW"
    )
    max_dc_kw: float | None = Field(
        default=None, gt=0.0, description="Max supported DC fast-charging speed in kW"
    )
    estimated_range_km: float | None = Field(
        default=None, gt=0.0, description="Rated or real-world range in km"
    )


# Properties to receive via API on vehicle registration
class VehicleCreate(VehicleBase):
    pass


# Properties to receive via API on vehicle update
class VehicleUpdate(BaseModel):
    make: str | None = None
    model: str | None = None
    vehicle_class: str | None = None
    battery_kwh: float | None = Field(default=None, gt=0.0)
    connector_type_ids: list[int] | None = Field(default=None, min_length=1)
    max_ac_kw: float | None = Field(default=None, gt=0.0)
    max_dc_kw: float | None = Field(default=None, gt=0.0)
    estimated_range_km: float | None = Field(default=None, gt=0.0)


# Properties returned to client
class VehicleResponse(VehicleBase):
    id: UUID
    user_id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
