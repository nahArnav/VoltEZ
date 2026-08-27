import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class AvailabilityObservation(Base):
    """Observed charger availability snapshots for analytics and ML training data."""

    __tablename__ = "availability_observations"
    __table_args__ = {"schema": "analytics"}

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    charger_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)

    port_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)

    is_available: Mapped[bool] = mapped_column(Boolean, nullable=False)

    observed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
