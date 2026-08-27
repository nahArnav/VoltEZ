from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, func
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class BookingEvent(Base):
    """Audit log for every booking status transition (BR-009)."""

    __tablename__ = "booking_events"
    __table_args__ = (
        Index("ix_booking_events_booking_id_created_at", "booking_id", "created_at"),
        {"schema": "app"},
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    booking_id: Mapped[object] = mapped_column(
        UUID(as_uuid=True), ForeignKey("app.bookings.id", ondelete="CASCADE"), nullable=False
    )

    old_status: Mapped[str | None] = mapped_column(String(50), nullable=True)

    new_status: Mapped[str] = mapped_column(String(50), nullable=False)

    actor: Mapped[str] = mapped_column(String(255), nullable=False)

    metadata_: Mapped[dict | None] = mapped_column("metadata", JSON, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
