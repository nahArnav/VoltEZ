import uuid
from datetime import datetime

import sqlalchemy
from sqlalchemy import UUID, CheckConstraint, DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class Vehicle(Base):
    __tablename__ = "vehicles"
    __table_args__ = (
        CheckConstraint(
            "battery_kwh IS NULL OR battery_kwh > 0",
            name="ck_vehicles_battery_positive",
        ),
        CheckConstraint(
            "max_ac_kw IS NULL OR max_ac_kw >= 0",
            name="ck_vehicles_max_ac_nonnegative",
        ),
        CheckConstraint(
            "max_dc_kw IS NULL OR max_dc_kw >= 0",
            name="ck_vehicles_max_dc_nonnegative",
        ),
        CheckConstraint(
            "estimated_range_km IS NULL OR estimated_range_km >= 0",
            name="ck_vehicles_range_nonnegative",
        ),
        CheckConstraint(
            "efficiency_wh_per_km IS NULL OR efficiency_wh_per_km > 0",
            name="ck_vehicles_efficiency_positive",
        ),
        CheckConstraint(
            "model_year IS NULL OR model_year BETWEEN 1886 AND 2100",
            name="ck_vehicles_model_year",
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

    make: Mapped[str | None] = mapped_column(String(100))
    model: Mapped[str | None] = mapped_column(String(100))
    model_year: Mapped[int | None] = mapped_column()

    vehicle_class: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
    )

    battery_kwh: Mapped[float | None] = mapped_column(Numeric(10, 3))
    max_ac_kw: Mapped[float | None] = mapped_column(Numeric(10, 3))
    max_dc_kw: Mapped[float | None] = mapped_column(Numeric(10, 3))
    estimated_range_km: Mapped[float | None] = mapped_column(Numeric(10, 2))
    efficiency_wh_per_km: Mapped[float | None] = mapped_column(Numeric(10, 2))

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
    )

    connector_types = sqlalchemy.orm.relationship(
        "ConnectorType", secondary="app.vehicle_connectors", backref="vehicles", lazy="selectin"
    )

    @property
    def connector_type_ids(self) -> list[int]:
        """Expose the join-table relationship through the public API contract."""
        return [connector.id for connector in self.connector_types]
