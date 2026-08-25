from sqlalchemy import Column, Integer, String, Float, DateTime, JSON, Index
from sqlalchemy.sql import func
from app.models.base import Base


class DemandHistory(Base):
    """Historical demand data per zone/time bucket for ML training."""
    __tablename__ = "demand_history"

    id = Column(Integer, primary_key=True, index=True)
    zone_id = Column(String, nullable=False, index=True)  # geospatial zone or charger cluster identifier
    time_bucket = Column(DateTime(timezone=True), nullable=False)  # start of 30/60-min bucket
    demand_count = Column(Integer, default=0)  # bookings/arrivals in this bucket
    occupancy = Column(Float, nullable=True)  # fraction of ports occupied, 0.0-1.0
    contextual_features = Column(JSON, nullable=True)  # weather, events, holiday, etc.
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("idx_demand_zone_time", "zone_id", "time_bucket"),
    )
