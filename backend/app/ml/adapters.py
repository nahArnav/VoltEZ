import logging
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.operations import ml_prediction_repo
from app.schemas.enums import BookingStatus
from app.schemas.ml_prediction import MLPredictionCreate
from app.services.ml_features import build_availability_features, build_demand_features
from database.models.booking import Booking
from database.models.ml_prediction import MLPrediction
from voltez_ml.serving import AvailabilityFeatureRequest, DemandFeatureRequest

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
        confidence: float,
    ) -> MLPrediction:
        """Saves every prediction to the database for auditability and drift monitoring."""
        prediction_in = MLPredictionCreate(
            target_id=entity_id,
            target_type=target_type,
            model_version=model_version,
            prediction_type=prediction_type,
            predicted_value=value,
            confidence_score=confidence,
        )
        prediction = await ml_prediction_repo.create(db, obj_in=prediction_in)
        await db.commit()
        logger.info(f"[ML] v{model_version} predicted {prediction_type}={value} for {entity_id}")
        return prediction

    @staticmethod
    async def predict_demand(db: AsyncSession, charger_id: UUID, model: Any = None) -> dict:
        """
        Model 1: Demand Forecasting
        Runs the verified joblib model using point-in-time features.
        """
        prediction_origin = datetime.now(UTC)
        features_df = build_demand_features(charger_id, prediction_origin)

        # If model is loaded, run inference. Else fallback.
        if model is not None:
            prediction = model.predict(
                DemandFeatureRequest(
                    zone_id=str(charger_id),
                    prediction_origin=prediction_origin,
                    features=features_df.iloc[0].to_dict(),
                )
            )
            expected_demand = float(prediction.expected_requests)
            confidence = 0.50 if prediction.used_fallback else 0.90
            model_version = prediction.model_id
        else:
            # Fallback heuristic
            logger.warning("Demand model not loaded. Using fallback.")
            expected_demand = 1.0
            confidence = 0.50
            model_version = "demand-fallback-v1"

        # Log wait time using UUID directly instead of string prefix
        await MLAdapter.log_prediction(
            db=db,
            entity_id=charger_id,
            target_type="charger",
            model_version=model_version,
            prediction_type="expected_demand",
            value=expected_demand,
            confidence=confidence,
        )

        return {"expected_demand": expected_demand, "confidence": confidence}

    @staticmethod
    async def predict_wait_time(
        db: AsyncSession, charger_id: UUID, port_id: UUID, model: Any = None
    ) -> dict:
        """
        Model 2: Availability / Wait-time Predictor
        Uses the probability of being 'available' and transforms it into expected wait time or availability score.
        """
        prediction_origin = datetime.now(UTC)
        target_time = prediction_origin + timedelta(minutes=30)
        features_df = build_availability_features(
            charger_id,
            port_id,
            prediction_origin,
            target_time,
        )
        decision = "unknown"
        probability_unavailable = None

        if model is not None:
            prediction = model.predict(
                AvailabilityFeatureRequest(
                    port_id=str(port_id),
                    prediction_origin=prediction_origin,
                    target_time=target_time,
                    features=features_df.iloc[0].to_dict(),
                )
            )
            decision = prediction.decision
            probability_unavailable = prediction.probability_unavailable
            model_version = prediction.model_id
            if probability_unavailable is not None:
                # Preserve the existing ranking heuristic while sourcing its
                # probability from the calibrated serving predictor.
                wait_minutes = probability_unavailable * 60.0
                confidence = 0.85
            else:
                result = await db.execute(
                    select(Booking).where(
                        Booking.charger_port_id == port_id,
                        Booking.status.in_(
                            [
                                BookingStatus.CHECKED_IN.value,
                                BookingStatus.CHARGING.value,
                            ]
                        ),
                    )
                )
                wait_minutes = len(result.scalars().all()) * 40.0
                confidence = 0.50
        else:
            # Fallback queue heuristic
            logger.warning("Availability model not loaded. Using fallback.")
            result = await db.execute(
                select(Booking).where(
                    Booking.charger_port_id == port_id,
                    Booking.status.in_(
                        [BookingStatus.CHECKED_IN.value, BookingStatus.CHARGING.value]
                    ),
                )
            )
            active_bookings = result.scalars().all()
            wait_minutes = len(active_bookings) * 40.0
            confidence = 0.50
            model_version = "availability-fallback-v1"

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
            model_version=model_version,
            prediction_type="wait_minutes",
            value=wait_minutes,
            confidence=confidence,
        )

        return {
            "wait_minutes": wait_minutes,
            "congestion_level": congestion,
            "confidence": confidence,
            "availability_decision": decision,
            "probability_unavailable": probability_unavailable,
        }


ml_adapter = MLAdapter()
