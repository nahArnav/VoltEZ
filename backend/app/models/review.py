from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, ARRAY
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.models.base import Base


class Review(Base):
    """Driver review after a charging session. Feeds reliability signal."""
    __tablename__ = "reviews"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("charging_sessions.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    rating = Column(Float, nullable=False)  # 1.0-5.0
    comment = Column(String, nullable=True)
    issue_flags = Column(ARRAY(String), nullable=True)  # e.g. ["charger_broken", "wrong_connector", "dirty"]
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    session = relationship("ChargingSession", back_populates="reviews")
    user = relationship("User", back_populates="reviews")
