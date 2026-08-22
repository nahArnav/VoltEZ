from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.models.base import Base


class ChargingSession(Base):
    """Actual charging event after check-in."""
    __tablename__ = "charging_sessions"

    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    check_in_at = Column(DateTime(timezone=True), nullable=True)
    start_at = Column(DateTime(timezone=True), nullable=True)
    end_at = Column(DateTime(timezone=True), nullable=True)
    energy_kwh = Column(Float, nullable=True)
    final_amount = Column(Float, nullable=True)
    status = Column(String, default="checked_in")  # "checked_in", "charging", "completed", "failed"
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    booking = relationship("Booking", back_populates="session")
    reviews = relationship("Review", back_populates="session", lazy="selectin")
