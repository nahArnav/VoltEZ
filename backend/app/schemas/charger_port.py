from uuid import UUID
from pydantic import BaseModel, Field
from typing import Literal, Optional
from datetime import datetime

# Shared properties
class ChargerPortBase(BaseModel):
    connector_type: str = Field(..., description="e.g., CCS2, Type2, CHAdeMO, GB_T")
    max_power_kw: float = Field(..., gt=0.0, description="Max power rating in kW")

# Properties to receive via API on creation
class ChargerPortCreate(ChargerPortBase):
    status: Literal["available", "occupied", "offline", "unknown"] = "available"

# Properties to receive via API on update
class ChargerPortUpdate(BaseModel):
    connector_type: Optional[str] = None
    max_power_kw: Optional[float] = Field(default=None, gt=0.0)
    status: Optional[str] = None

# Properties to return to client
class ChargerPortResponse(ChargerPortBase):
    id: UUID
    charger_id: UUID
    status: str
    created_at: datetime

    class Config:
        from_attributes = True