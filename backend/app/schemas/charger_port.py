from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


# Shared properties
class ChargerPortBase(BaseModel):
    connector_type_id: int
    max_power_kw: float = Field(..., gt=0.0, description="Max power rating in kW")
    port_number: int = Field(..., gt=0)


# Properties to receive via API on creation
class ChargerPortCreate(ChargerPortBase):
    is_active: bool = True


# Properties to receive via API on update
class ChargerPortUpdate(BaseModel):
    connector_type_id: int | None = None
    max_power_kw: float | None = Field(default=None, gt=0.0)
    is_active: bool | None = None


# Properties to return to client
class ChargerPortResponse(ChargerPortBase):
    id: UUID
    charger_id: UUID
    is_active: bool

    model_config = ConfigDict(from_attributes=True)
