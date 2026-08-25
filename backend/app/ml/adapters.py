from datetime import datetime, timezone
import logging
from uuid import UUID
from typing import Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from database.models.ml_prediction import MLPrediction
from app.schemas.enums import BookingStatus
from database.models.booking import Booking
from database.models.charging_session import ChargingSession
from app.repositories.operations import ml_prediction_repo
from app.schemas.ml_prediction import MLPredictionCreate
from app.services.ml_features import build_demand_features, build_availability_features

logger = logging.getLogger(__name__)

class MLAdapter:
    """
    ML Inference Adapter.
    Integrates point-in-time features with actual scikit-learn models.
    """

    @staticmethod
    async def log_prediction(
        db: AsyncSession,
        entity_id: UUID,
        target_type: str,
        model_version: str,
        prediction_type: str,
        value: float,
        confidence: float
    ) -> MLPrediction:
        """Saves every prediction to the database for auditability and drift monitoring."""
        prediction_in = MLPredictionCreate(
            target_id=entity_id,
            target_type=target_type,
            model_version=model_version,
            prediction_type=prediction_type,
            predicted_value=value,
            confidence_score=confidence
        )
        prediction = await ml_prediction_repo.create(db, obj_in=prediction_in)
        logger.info(f"[ML] v{model_version} predicted {prediction_type}={value} for {entity_id}")
        return prediction

    @staticmethod
    async def predict_demand(db: AsyncSession, charger_id: UUID, model: Any = None) -> dict:
        """
        Model 1: Demand Forecasting
        Runs the verified joblib model using point-in-time features.
        """
        features_df = build_demand_features(charger_id)
        
        # If model is loaded, run inference. Else fallback.
        if model is not None:
            # Predict returns an array, take first element
            expected_demand = float(model.predict(features_df)[0])
            confidence = 0.90 # High confidence if model succeeds
        else:
            # Fallback heuristic
            logger.warning("Demand model not loaded. Using fallback.")
            expected_demand = 1.0
            confidence = 0.50
            
        # Log wait time using UUID directly instead of string prefix
        await MLAdapter.log_prediction(
            db=db,
            entity_id=charger_id,
            target_type="charger",
            model_version="voltez-demand-60m-pune-v1",
            prediction_type="expected_demand",
            value=expected_demand,
            confidence=confidence
        )
        
        return {
            "expected_demand": expected_demand,
            "confidence": confidence
        }

    @staticmethod
    async def predict_wait_time(db: AsyncSession, charger_id: UUID, port_id: UUID, model: Any = None) -> dict:
        """
        Model 2: Availability / Wait-time Predictor
        Uses the probability of being 'available' and transforms it into expected wait time or availability score.
        """
        features_df = build_availability_features(charger_id, port_id)
        
        if model is not None:
            # predict_proba returns probabilities for classes. 
            # Assuming class 1 is 'unavailable' and class 0 is 'available'.
            proba = model.predict_proba(features_df)[0]
            if len(proba) > 1:
                prob_unavailable = float(proba[1]) # probability of being unavailable/occupied
            else:
                prob_unavailable = float(proba[0])
            
            # Translate probability to wait minutes (dummy transformation for now)
            wait_minutes = prob_unavailable * 60.0
            confidence = 0.85
        else:
            # Fallback queue heuristic
            logger.warning("Availability model not loaded. Using fallback.")
            result = await db.execute(
                select(Booking).where(Booking.charger_port_id == port_id, Booking.status.in_([BookingStatus.CHECKED_IN.value, BookingStatus.CHARGING.value]))
            )
            active_bookings = result.scalars().all()
            wait_minutes = len(active_bookings) * 40.0
            confidence = 0.50
            
        if wait_minutes == 0:
            congestion = "LOW"
            congestion_val = 0.0
        elif wait_minutes <= 40:
            congestion = "MEDIUM"
            congestion_val = 1.0
        else:
            congestion = "HIGH"
            congestion_val = 2.0
        
        # Log prediction
        await MLAdapter.log_prediction(
            db=db,
            entity_id=port_id,
            target_type="port",
            model_version="voltez-availability-pune-v1",
            prediction_type="wait_minutes",
            value=wait_minutes,
            confidence=confidence
        )
        
        return {
            "wait_minutes": wait_minutes,
            "congestion_level": congestion,
            "confidence": confidence
        }

ml_adapter = MLAdapter()
