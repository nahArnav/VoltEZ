import uuid
from uuid import uuid4

from geoalchemy2 import Geometry
import sqlalchemy
from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Numeric, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class Charger(Base):
    __tablename__ = "chargers"
    __table_args__ = (
    CheckConstraint(
        "length(trim(name)) > 0",
        name="ck_charger_name_not_blank",
    ),
    CheckConstraint(
        "length(trim(charger_type)) > 0",
        name="ck_charger_type_not_blank",
    ),
    CheckConstraint(
        "power_kw > 0",
        name="ck_charger_power_positive",
    ),
    CheckConstraint(
        "status IN ('available', 'unavailable', 'maintenance', 'offline')",
        name="ck_charger_status",
    ),
    CheckConstraint(
        "verification_status IN ('pending', 'verified', 'rejected')",
        name="ck_charger_verification_status",
    ),
    {"schema": "app"},
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.businesses.id"),
        nullable=False,
    )

    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    location: Mapped[object] = mapped_column(
    Geometry(
        geometry_type="POINT",
        srid=4326,
        spatial_index=False,
    ),
    nullable=False,
    )

    address_text: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    charger_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )

    power_kw: Mapped[float] = mapped_column(
        Numeric(8, 2),
        nullable=False,
    )

    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="available",
    )

    verification_status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="pending",
    )

    access_notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    updated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
    
    reliability_score: Mapped[float] = mapped_column(
        Numeric(5, 2),
        default=100.0,
        nullable=False,
    )

    ports = sqlalchemy.orm.relationship("ChargerPort", back_populates="charger", lazy="selectin")
