import uuid
from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class AvailabilityObservation(Base):
    """Observed charger availability snapshots for analytics and ML training data."""

    __tablename__ = "analytics_availability_observations"
    __table_args__ = {"schema": "app"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    charger_port_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("app.charger_ports.id"), nullable=False
    )

    observed_status: Mapped[str] = mapped_column(
        String(30), nullable=False
    )

    confidence: Mapped[float] = mapped_column(
        Float, nullable=False, default=0.5
    )

    source: Mapped[str] = mapped_column(
        String(50), nullable=False
    )

    observed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
