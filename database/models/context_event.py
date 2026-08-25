import uuid
from datetime import datetime

from sqlalchemy import DateTime, Float, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class ContextEvent(Base):
    """External context events (weather, holidays, local events) used by ML demand forecasting."""

    __tablename__ = "context_events"
    __table_args__ = {"schema": "app"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    event_type: Mapped[str] = mapped_column(
        String(100), nullable=False
    )

    description: Mapped[str | None] = mapped_column(
        String(500), nullable=True
    )

    expected_impact: Mapped[float] = mapped_column(
        Float, nullable=False, default=0.0
    )

    metadata_: Mapped[dict | None] = mapped_column(
        "metadata", JSONB, nullable=True
    )

    starts_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )

    ends_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
