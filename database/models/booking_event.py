import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class BookingEvent(Base):
    """Audit log for every booking status transition (BR-009)."""

    __tablename__ = "booking_events"
    __table_args__ = {"schema": "app"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    booking_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("app.bookings.id"), nullable=False
    )

    old_status: Mapped[str | None] = mapped_column(
        String(30), nullable=True
    )

    new_status: Mapped[str] = mapped_column(
        String(30), nullable=False
    )

    actor: Mapped[str] = mapped_column(
        String(100), nullable=False
    )

    metadata_: Mapped[dict | None] = mapped_column(
        "metadata", JSONB, nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
