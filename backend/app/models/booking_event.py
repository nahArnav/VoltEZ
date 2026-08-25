from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.models.base import Base


class BookingEvent(Base):
    """Audit trail for booking state transitions (BR-009)."""
    __tablename__ = "booking_events"

    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id", ondelete="CASCADE"), nullable=False, index=True)
    old_status = Column(String, nullable=True)  # null for initial creation
    new_status = Column(String, nullable=False)
    actor = Column(String, nullable=False)  # "user:<id>", "system", "admin:<id>"
    metadata_ = Column("metadata", JSON, nullable=True)  # additional context (reason, etc.)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    booking = relationship("Booking", back_populates="events")
