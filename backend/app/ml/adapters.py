from datetime import datetime, timezone
import logging
import warnings
from uuid import UUID
from typing import Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import numpy as np
import pandas as pd
import joblib

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
    Loads trained models from deployment bundles with SHA-256 verification,
    then runs point-in-time feature inference. Falls back to heuristics
    when models are unavailable.
    """

    def __init__(self):
        self._demand_bundle = None
        self._availability_bundle = None

    def load_demand_model(self, bundle):
        """Load the demand model from a verified ModelBundle."""
        self._demand_bundle = bundle
        if bundle:
            # The demand model payload contains 'model' and 'features' keys
            # We store the raw joblib payload for direct .predict() calls
            self._demand_model = bundle.model
            self._demand_features = bundle.feature_order
            logger.info(
                "[MLAdapter] Demand model loaded: %s (features=%d)",
                bundle.model_id,
                bundle.feature_count,
            )
        else:
            self._demand_model = None
            self._demand_features = []

    def load_availability_model(self, bundle):
        """Load the availability model from a verified ModelBundle."""
        self._availability_bundle = bundle
        if bundle:
            # Availability payload contains base_model + calibrator
            payload = bundle.model
            if isinstance(payload, dict) and 'base_model' in payload:
                self._availability_base_model = payload['base_model']
                self._availability_calibrator = payload['calibrator']
                self._availability_thresholds = payload.get('thresholds', {})
            else:
                # Fallback: treat the loaded object as a single model
                self._availability_base_model = payload
                self._availability_calibrator = None
                self._availability_thresholds = {}
            self._availability_features = bundle.feature_order
            logger.info(
                "[MLAdapter] Availability model loaded: %s (features=%d)",
                bundle.model_id,
                bundle.feature_count,
            )
        else:
            self._availability_base_model = None
            self._availability_calibrator = None
            self._availability_thresholds = {}
            self._availability_features = []

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
        logger.info(f"[ML] v{model_version} predicted {prediction_type}={value:.4f} for {entity_id}")
        return prediction

    async def predict_demand(self, db: AsyncSession, charger_id: UUID) -> dict:
        """
        Model 1: Demand Forecasting
        Uses the loaded and hash-verified joblib model to predict expected
        charging requests in a 60-minute window.
        """
        features_df = build_demand_features(charger_id)

        if self._demand_model is not None:
            try:
                with warnings.catch_warnings():
                    warnings.filterwarnings(
                        "ignore",
                        message="Setting the shape on a NumPy array has been deprecated.*",
                        category=DeprecationWarning,
                    )
                    prediction = self._demand_model.predict(features_df)
                    expected_demand = float(max(prediction[0], 0.0))  # Demand cannot be negative
                    confidence = 0.90
                    model_version = self._demand_bundle.model_id if self._demand_bundle else "unknown"
            except Exception as e:
                logger.error("[MLAdapter] Demand prediction failed: %s. Using fallback.", e)
                expected_demand = 1.0
                confidence = 0.50
                model_version = "fallback"
        else:
            logger.warning("[MLAdapter] Demand model not loaded. Using heuristic fallback.")
            expected_demand = 1.0
            confidence = 0.50
            model_version = "heuristic-fallback"

        await MLAdapter.log_prediction(
            db=db,
            entity_id=charger_id,
            target_type="charger",
            model_version=model_version,
            prediction_type="expected_demand",
            value=expected_demand,
            confidence=confidence
        )

        return {
            "expected_demand": expected_demand,
            "confidence": confidence,
            "model_version": model_version,
        }

    async def predict_availability(self, db: AsyncSession, charger_id: UUID, port_id: UUID) -> dict:
        """
        Model 2: Availability Prediction
        Uses the calibrated availability model to estimate the probability
        that a charger port will be unavailable at the driver's ETA.
        """
        features_df = build_availability_features(charger_id, port_id)

        if self._availability_base_model is not None:
            try:
                # Predict raw probability of unavailability
                with warnings.catch_warnings():
                    warnings.filterwarnings(
                        "ignore",
                        message="Could not find the number of physical cores.*",
                        category=UserWarning,
                    )
                    raw_proba = self._availability_base_model.predict_proba(features_df)
                    if raw_proba.shape[1] > 1:
                        prob_unavailable = float(raw_proba[0, 1])
                    else:
                        prob_unavailable = float(raw_proba[0, 0])

                # Apply Platt calibration if available
                if self._availability_calibrator is not None:
                    logits = np.log(np.clip(prob_unavailable, 1e-6, 1 - 1e-6) / (1 - np.clip(prob_unavailable, 1e-6, 1 - 1e-6)))
                    calibrated_proba = self._availability_calibrator.predict_proba(logits.reshape(1, -1))
                    prob_unavailable = float(calibrated_proba[0, 1])

                prob_unavailable = float(np.clip(prob_unavailable, 1e-6, 1 - 1e-6))
                confidence = 0.85
                model_version = self._availability_bundle.model_id if self._availability_bundle else "unknown"

                # Apply thresholds for three-state decision
                available_threshold = self._availability_thresholds.get('available_max_probability_unavailable', 0.1674)
                unavailable_threshold = self._availability_thresholds.get('unavailable_min_probability_unavailable', 0.4385)

                if prob_unavailable <= available_threshold:
                    availability_decision = "available"
                elif prob_unavailable >= unavailable_threshold:
                    availability_decision = "unavailable"
                else:
                    availability_decision = "unknown"

            except Exception as e:
                logger.error("[MLAdapter] Availability prediction failed: %s. Using fallback.", e)
                prob_unavailable = 0.5
                confidence = 0.50
                availability_decision = "unknown"
                model_version = "fallback"
        else:
            # Fallback: count active bookings on this port
            logger.warning("[MLAdapter] Availability model not loaded. Using booking heuristic.")
            result = await db.execute(
                select(Booking).where(
                    Booking.charger_port_id == port_id,
                    Booking.status.in_([BookingStatus.CHECKED_IN.value, BookingStatus.CHARGING.value])
                )
            )
            active_bookings = result.scalars().all()
            wait_minutes = len(active_bookings) * 40.0
            prob_unavailable = min(wait_minutes / 60.0, 1.0) if wait_minutes > 0 else 0.05
            confidence = 0.50
            availability_decision = "unavailable" if wait_minutes > 0 else "available"
            model_version = "heuristic-fallback"

        # Derive congestion level from wait probability
        if prob_unavailable <= 0.15:
            congestion = "LOW"
        elif prob_unavailable <= 0.5:
            congestion = "MEDIUM"
        else:
            congestion = "HIGH"

        await MLAdapter.log_prediction(
            db=db,
            entity_id=port_id,
            target_type="port",
            model_version=model_version,
            prediction_type="availability_probability",
            value=prob_unavailable,
            confidence=confidence
        )

        return {
            "probability_unavailable": prob_unavailable,
            "availability_decision": availability_decision,
            "congestion_level": congestion,
            "confidence": confidence,
            "model_version": model_version,
        }

    # Keep the old method signature for backward compatibility
    async def predict_wait_time(self, db: AsyncSession, charger_id: UUID, port_id: UUID) -> dict:
        """
        Legacy method: translates availability prediction into estimated wait minutes.
        Prefer predict_availability() for new code.
        """
        result = await self.predict_availability(db, charger_id, port_id)
        prob_unavailable = result["probability_unavailable"]
        # Convert probability to estimated wait minutes
        wait_minutes = prob_unavailable * 60.0
        return {
            "wait_minutes": wait_minutes,
            "congestion_level": result["congestion_level"],
            "confidence": result["confidence"],
        }


# Singleton instance - models loaded at startup via main.py lifespan
ml_adapter = MLAdapter()
