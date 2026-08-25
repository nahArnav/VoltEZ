from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Index
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from geoalchemy2 import Geography
from app.models.base import Base


class Charger(Base):
    __tablename__ = "chargers"

    id = Column(Integer, primary_key=True, index=True)
    business_id = Column(Integer, ForeignKey("businesses.id", ondelete="CASCADE"), nullable=False, index=True)
    name = Column(String, nullable=False)
    location = Column(Geography(geometry_type="POINT", srid=4326), nullable=False)
    power_kw = Column(Float, nullable=False)
    access_type = Column(String, default="public")  # "public", "private", "restricted"
    base_price = Column(Float, nullable=False)  # INR per kWh
    status = Column(String, default="active")  # "active", "paused", "inactive"
    reliability_score = Column(Float, default=0.5)  # Bayesian-smoothed, 0.0-1.0
    parking_info = Column(String, nullable=True)
    amenities = Column(String, nullable=True)  # comma-separated or JSON later
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    business = relationship("Business", back_populates="chargers")
    ports = relationship("ChargerPort", back_populates="charger", lazy="selectin")
    status_events = relationship("ChargerStatusEvent", back_populates="charger", lazy="selectin")

    __table_args__ = (
        # GiST spatial index for PostGIS nearby queries
        Index("idx_charger_location", location, postgresql_using="gist"),
    )
