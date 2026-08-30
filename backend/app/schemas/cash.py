from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field


class CashOtpVerifyRequest(BaseModel):
    """The six-digit code shown to the driver after a cash reservation."""

    code: str = Field(
        ...,
        min_length=6,
        max_length=6,
        pattern=r"^\d{6}$",
        description="Six-digit cash reservation code supplied by the driver",
    )


class CashOtpVerificationResponse(BaseModel):
    booking_id: UUID
    session_id: UUID
    booking_status: str
    session_status: Literal["reserved", "charging", "completed", "failed"]
    started_at: datetime | None = None
    payment_method: Literal["cash"] = "cash"


class CashSettlementResponse(BaseModel):
    payment_id: UUID
    booking_id: UUID
    amount: float
    currency: str
    method: Literal["cash"] = "cash"
    status: Literal["pending", "completed"]
    verified_at: datetime | None = None
