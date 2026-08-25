import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class ChargingSession(Base):
    __tablename__ = "charging_sessions"
    __table_args__ = (
    CheckConstraint(
        "ended_at IS NULL OR started_at IS NULL OR ended_at >= started_at",
        name="ck_charging_sessions_end_after_start",
    ),
    CheckConstraint(
        "energy_kwh IS NULL OR energy_kwh >= 0",
        name="ck_charging_sessions_energy_nonnegative",
    ),
    CheckConstraint(
        "amount IS NULL OR amount >= 0",
        name="ck_charging_sessions_amount_nonnegative",
    ),
    {"schema": "app"},
)

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    charger_port_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.charger_ports.id"),
        nullable=False,
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.users.id"),
        nullable=False,
    )

    booking_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.bookings.id"),
        nullable=True,
    )

    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="reserved",
    )

    reserved_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    energy_kwh: Mapped[float | None] = mapped_column(
        Numeric(10, 3),
        nullable=True,
    )

    amount: Mapped[float | None] = mapped_column(
        Numeric(10, 2),
        nullable=True,
    )
