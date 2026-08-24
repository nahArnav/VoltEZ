from datetime import datetime, timezone
import logging
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.ml_prediction import MLPrediction
from app.models.booking import Booking
from app.models.charging_session import ChargingSession
from app.repositories.operations import ml_prediction_repo
from app.schemas.ml_prediction import MLPredictionCreate

logger = logging.getLogger(__name__)

class MLAdapter:
    """
    ML Inference Adapter.
    For this prototype, it uses deterministic heuristic models (queue math, rolling averages)
    as explicitly recommended by the playbook, avoiding bloated dependencies.
    """

    @staticmethod
    async def log_prediction(
        db: AsyncSession,
        entity_id: str,
        model_name: str,
        model_version: str,
        prediction_type: str,
        value: float,
        confidence: float
    ) -> MLPrediction:
        """Saves every prediction to the database for auditability and drift monitoring."""
        prediction_in = MLPredictionCreate(
            entity_id=entity_id,
            model_name=model_name,
            model_version=model_version,
            prediction_type=prediction_type,
            value=value,
            confidence=confidence,
            generated_at=datetime.now(timezone.utc)
        )
        prediction = await ml_prediction_repo.create(db, obj_in=prediction_in)
        logger.info(f"[ML] {model_name} v{model_version} predicted {prediction_type}={value} for {entity_id}")
        return prediction

    @staticmethod
    async def predict_demand(db: AsyncSession, charger_id: int) -> dict:
        """
        Model A: Demand Forecasting
        Baseline heuristic: Peak hours (17-21) and weekends increase demand.
        Returns expected booking count in the next hour.
        """
        now = datetime.now(timezone.utc)
        hour = now.hour
        is_weekend = now.weekday() >= 5
        
        # Base demand assumption
        base_demand = 1.0
        
        if 17 <= hour <= 21:
            base_demand += 2.5
        elif 9 <= hour <= 12:
            base_demand += 1.5
            
        if is_weekend:
            base_demand += 1.0
            
        expected_demand = round(base_demand, 2)
        confidence = 0.85 # baseline confidence
        
        await MLAdapter.log_prediction(
            db=db,
            entity_id=f"charger_{charger_id}",
            model_name="demand_forecast",
            model_version="1.0-heuristic",
            prediction_type="expected_demand",
            value=expected_demand,
            confidence=confidence
        )
        
        return {
            "expected_demand": expected_demand,
            "confidence": confidence
        }

    @staticmethod
    async def predict_wait_time(db: AsyncSession, charger_id: int, port_id: int) -> dict:
        """
        Model B: Wait-time / Occupancy Predictor
        Baseline heuristic: Queue from current active sessions and bookings.
        """
        # 1. Count active sessions for this port
        # In a real app we would join Booking with ChargingSession correctly.
        # For prototype, if there's a live charging session, assume 30 mins remaining.
        # If there are pending bookings, add 45 mins per booking.
        
        result = await db.execute(
            select(Booking).where(Booking.port_id == port_id, Booking.status.in_(["checked_in", "charging"]))
        )
        active_bookings = result.scalars().all()
        
        wait_minutes = len(active_bookings) * 40.0 # 40 mins per active car
        
        # Classify congestion
        if wait_minutes == 0:
            congestion = "LOW"
            congestion_val = 0.0
        elif wait_minutes <= 40:
            congestion = "MEDIUM"
            congestion_val = 1.0
        else:
            congestion = "HIGH"
            congestion_val = 2.0
            
        confidence = 0.90
        
        # Log wait time
        await MLAdapter.log_prediction(
            db=db,
            entity_id=f"port_{port_id}",
            model_name="wait_prediction",
            model_version="1.0-queue",
            prediction_type="wait_minutes",
            value=wait_minutes,
            confidence=confidence
        )
        
        # Log congestion level
        await MLAdapter.log_prediction(
            db=db,
            entity_id=f"port_{port_id}",
            model_name="wait_prediction",
            model_version="1.0-queue",
            prediction_type="congestion_level",
            value=congestion_val,
            confidence=confidence
        )
        
        return {
            "wait_minutes": wait_minutes,
            "congestion_level": congestion,
            "confidence": confidence
        }

ml_adapter = MLAdapter()
