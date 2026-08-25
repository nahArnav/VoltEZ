from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Boolean, Index
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.models.base import Base


class AvailabilityWindow(Base):
    __tablename__ = "availability_windows"

    id = Column(Integer, primary_key=True, index=True)
    port_id = Column(Integer, ForeignKey("charger_ports.id", ondelete="CASCADE"), nullable=False)
    start_at = Column(DateTime(timezone=True), nullable=False)
    end_at = Column(DateTime(timezone=True), nullable=False)
    source = Column(String, default="owner")  # "owner", "ai_recommendation", "admin"
    price_override = Column(Float, nullable=True)  # overrides charger base_price if set
    status = Column(String, default="active")  # "active", "paused", "cancelled"
    is_recurring = Column(Boolean, default=False)
    recurrence_rule = Column(String, nullable=True)  # e.g. "RRULE:FREQ=WEEKLY;BYDAY=TU,TH"
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    port = relationship("ChargerPort", back_populates="availability_windows")

    __table_args__ = (
        # Index for querying available slots by port and time range
        Index("idx_availability_port_time", "port_id", "start_at", "end_at"),
    )
