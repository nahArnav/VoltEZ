from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, ARRAY
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.models.base import Base


class Vehicle(Base):
    __tablename__ = "vehicles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    make = Column(String, nullable=False)
    model = Column(String, nullable=False)
    battery_kwh = Column(Float, nullable=False)
    connector_types = Column(ARRAY(String), nullable=False)  # e.g. ["CCS2", "Type2"]
    max_ac_kw = Column(Float, nullable=True)
    max_dc_kw = Column(Float, nullable=True)
    estimated_range_km = Column(Float, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    user = relationship("User", back_populates="vehicles")
    bookings = relationship("Booking", back_populates="vehicle", lazy="selectin")
