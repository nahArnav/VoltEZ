import uuid

from sqlalchemy import Boolean, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base import Base


class VehicleConnector(Base):
    __tablename__ = "vehicle_connectors"
    __table_args__ = (
        {"schema": "app"},
    )

    vehicle_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.vehicles.id", ondelete="CASCADE"),
        primary_key=True,
    )

    connector_type_id: Mapped[int] = mapped_column(
        ForeignKey("app.connector_types.id"),
        primary_key=True,
    )

    is_preferred: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
    )