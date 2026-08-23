import uuid
from datetime import time

from sqlalchemy import Boolean, ForeignKey, Integer, Time
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class ChargerAvailability(Base):
    __tablename__ = "charger_availability"
    __table_args__ = {"schema": "app"}

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
