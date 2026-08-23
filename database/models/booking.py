import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import ExcludeConstraint, UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import expression

from database.base_class import Base


class Booking(Base):
    __tablename__ = "bookings"
    __table_args__ = (
    ExcludeConstraint(
        ("charger_port_id", "="),
        (
            expression.text(
                "tstzrange(start_at, end_at, '[)')"
            ),
            "&&",
        ),
        name="excl_bookings_port_time",
        using="gist",
    ),
    {"schema": "app"},
)

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.users.id"),
        nullable=False,
    )

    charger_port_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.charger_ports.id"),
        nullable=False,
    )

    start_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    end_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="confirmed",
    )

    estimated_amount: Mapped[float | None] = mapped_column(
        Numeric(10, 2),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    cancelled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
