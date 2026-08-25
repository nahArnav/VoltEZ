from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.models.base import Base


class ChargerPort(Base):
    __tablename__ = "charger_ports"

    id = Column(Integer, primary_key=True, index=True)
    charger_id = Column(Integer, ForeignKey("chargers.id", ondelete="CASCADE"), nullable=False, index=True)
    connector_type = Column(String, nullable=False)  # "CCS2", "Type2", "CHAdeMO", etc.
    max_power_kw = Column(Float, nullable=False)
    status = Column(String, default="available")  # "available", "occupied", "offline", "unknown"
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    charger = relationship("Charger", back_populates="ports")
    availability_windows = relationship("AvailabilityWindow", back_populates="port", lazy="selectin")
    bookings = relationship("Booking", back_populates="port", lazy="selectin")
    status_events = relationship("ChargerStatusEvent", back_populates="port", lazy="selectin")
