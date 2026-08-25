from sqlalchemy import Column, Integer, String, Float, DateTime, Index
from sqlalchemy.sql import func
from app.models.base import Base


class MLPrediction(Base):
    """
    Stores ML predictions for auditability.
    Every prediction records model name, version, confidence and timestamp.
    """
    __tablename__ = "ml_predictions"

    id = Column(Integer, primary_key=True, index=True)
    entity_id = Column(String, nullable=False, index=True)  # charger_id, zone_id, etc.
    model_name = Column(String, nullable=False)  # "demand_forecast", "wait_prediction"
    model_version = Column(String, nullable=False)
    prediction_type = Column(String, nullable=False)  # "demand", "wait_minutes", "congestion_level"
    value = Column(Float, nullable=False)
    confidence = Column(Float, nullable=True)
    generated_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("idx_prediction_entity_time", "entity_id", "generated_at"),
    )
