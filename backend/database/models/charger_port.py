from uuid import uuid4

import sqlalchemy
from sqlalchemy import Boolean, CheckConstraint, ForeignKey, Numeric, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class ChargerPort(Base):
    __tablename__ = "charger_ports"
    __table_args__ = (
        UniqueConstraint(
            "charger_id",
            "port_number",
            name="uq_charger_port_number",
        ),
        CheckConstraint(
            "port_number > 0",
            name="ck_charger_port_number_positive",
        ),
        CheckConstraint(
            "max_power_kw > 0",
            name="ck_charger_port_power_positive",
        ),
        {"schema": "app"},
    )

    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    charger_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.chargers.id"),
        nullable=False,
    )

    connector_type_id: Mapped[int] = mapped_column(
        ForeignKey("app.connector_types.id"),
        nullable=False,
    )

    port_number: Mapped[int] = mapped_column(
        nullable=False,
    )

    max_power_kw: Mapped[float] = mapped_column(
        Numeric(8, 2),
        nullable=False,
    )

    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
    )

    charger = sqlalchemy.orm.relationship("Charger", back_populates="ports", lazy="selectin")
