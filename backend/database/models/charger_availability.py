import uuid
from datetime import time

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    Integer,
    Time,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class ChargerAvailability(Base):
    __tablename__ = "charger_availability"
    __table_args__ = (
        CheckConstraint(
            "day_of_week BETWEEN 0 AND 6",
            name="ck_charger_availability_day_of_week",
        ),
        CheckConstraint(
            "end_local_time > start_local_time",
            name="ck_charger_availability_time_order",
        ),
        UniqueConstraint(
            "charger_port_id",
            "day_of_week",
            "start_local_time",
            "end_local_time",
            "is_unavailable",
            name="uq_charger_availability_schedule",
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

    day_of_week: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    start_local_time: Mapped[time] = mapped_column(
        Time,
        nullable=False,
    )

    end_local_time: Mapped[time] = mapped_column(
        Time,
        nullable=False,
    )

    is_unavailable: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
    )
