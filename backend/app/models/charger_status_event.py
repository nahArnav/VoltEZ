from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.models.base import Base


class ChargerStatusEvent(Base):
    """
    No-IoT trust model: every status update records its source and confidence.
    Sources: OWNER, DRIVER_CHECKIN, DRIVER_CHECKOUT, BOOKING_DERIVED, ADMIN, CPO_IOT (future).
    """
    __tablename__ = "charger_status_events"

    id = Column(Integer, primary_key=True, index=True)
    charger_id = Column(Integer, ForeignKey("chargers.id", ondelete="CASCADE"), nullable=False, index=True)
    port_id = Column(Integer, ForeignKey("charger_ports.id", ondelete="CASCADE"), nullable=True, index=True)
    status = Column(String, nullable=False)  # "available", "occupied", "offline", "unknown"
    source = Column(String, nullable=False)  # "OWNER", "DRIVER_CHECKIN", "DRIVER_CHECKOUT", "BOOKING_DERIVED", "ADMIN"
    confidence = Column(Float, default=0.5)  # 0.0-1.0, decays over time
    observed_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    charger = relationship("Charger", back_populates="status_events")
    port = relationship("ChargerPort", back_populates="status_events")
