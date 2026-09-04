import logging
import warnings
from datetime import datetime
from typing import Any
from uuid import UUID

import numpy as np
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.operations import ml_prediction_repo
from app.schemas.enums import BookingStatus
from app.schemas.ml_prediction import MLPredictionCreate
from app.services.ml_features import build_availability_features, build_demand_features
from database.models.booking import Booking
from database.models.ml_prediction import MLPrediction

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
        self._demand_model = None
        self._demand_features = []
        self._availability_base_model = None
        self._availability_calibrator = None
        self._availability_thresholds = {}
        self._availability_features = []
        self._waiting_bundle = None
        self._waiting_model = None
        self._waiting_features = []
        self._reliability_bundle = None
        self._reliability_base_model = None
        self._reliability_calibrator = None
        self._reliability_thresholds = {}
        self._reliability_features = []

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
            if isinstance(payload, dict) and "base_model" in payload:
                self._availability_base_model = payload["base_model"]
                self._availability_calibrator = payload["calibrator"]
                self._availability_thresholds = payload.get("thresholds", {})
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

    def load_waiting_time_model(self, bundle):
        """Load Model 3 when a promoted deployment bundle is present."""
        self._waiting_bundle = bundle
        self._waiting_model = bundle.model if bundle else None
        self._waiting_features = bundle.feature_order if bundle else []

    def load_reliability_model(self, bundle):
        """Load Model 4 when a promoted deployment bundle is present."""
        self._reliability_bundle = bundle
        payload = bundle.model if bundle else None
        if isinstance(payload, dict) and "base_model" in payload:
            self._reliability_base_model = payload["base_model"]
            self._reliability_calibrator = payload.get("calibrator")
            self._reliability_thresholds = payload.get("thresholds", {})
            self._reliability_features = bundle.feature_order
        else:
            self._reliability_base_model = None
            self._reliability_calibrator = None
            self._reliability_thresholds = {}
            self._reliability_features = []

    @staticmethod
    def _align_features(features_df, expected_features: list[str]):
        """Return a frame in the exact order frozen by the model contract.

        The live builders deliberately expose the complete feature set so they
        can evolve independently.  Estimators, however, require the same
        column count and ordering used during training.  Selecting the bundle's
        contract here prevents silent column drift and produces a clear error
        (which the caller can safely fall back from) when a new required
        feature has not yet been wired into serving.
        """
        if not expected_features:
            return features_df
        missing = [name for name in expected_features if name not in features_df.columns]
        if missing:
            raise ValueError(f"serving feature builder is missing model features: {missing}")
        return features_df.loc[:, expected_features]

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
        logger.info(
            f"[ML] v{model_version} predicted {prediction_type}={value:.4f} for {entity_id}"
        )
        return prediction

    async def predict_demand(
        self,
        db: AsyncSession,
        charger_id: UUID,
        model: Any | None = None,
    ) -> dict:
        """
        Model 1: Demand Forecasting
        Uses the loaded and hash-verified joblib model to predict expected
        charging requests in a 60-minute window.
        """
        features_df = await build_demand_features(db, charger_id)

        # ``model`` is accepted for compatibility with older analytics
        # callers. Prefer the hash-verified bundle loaded at startup; only
        # use an explicitly supplied estimator when no bundle is available.
        predictor = self._demand_model if self._demand_model is not None else model
        if predictor is not None:
            try:
                model_features = self._align_features(features_df, self._demand_features)
                with warnings.catch_warnings():
                    warnings.filterwarnings(
                        "ignore",
                        message="Setting the shape on a NumPy array has been deprecated.*",
                        category=DeprecationWarning,
                    )
                    prediction = predictor.predict(model_features)
                    expected_demand = float(max(prediction[0], 0.0))  # Demand cannot be negative
                    confidence = 0.90
                    model_version = (
                        self._demand_bundle.model_id if self._demand_bundle else "unknown"
                    )
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
            confidence=confidence,
        )

        return {
            "expected_demand": expected_demand,
            "confidence": confidence,
            "model_version": model_version,
        }

    async def predict_availability(
        self,
        db: AsyncSession,
        charger_id: UUID,
        port_id: UUID,
        *,
        features_df: Any | None = None,
        target_time: datetime | None = None,
    ) -> dict:
        """
        Model 2: Availability Prediction
        Uses the calibrated availability model to estimate the probability
        that a charger port will be unavailable at the driver's ETA.
        """
        features_df = (
            features_df
            if features_df is not None
            else await build_availability_features(
                db,
                charger_id,
                port_id,
                target_time=target_time,
            )
        )

        if self._availability_base_model is not None:
            try:
                model_features = self._align_features(features_df, self._availability_features)
                # Predict raw probability of unavailability
                with warnings.catch_warnings():
                    warnings.filterwarnings(
                        "ignore",
                        message="Could not find the number of physical cores.*",
                        category=UserWarning,
                    )
                    raw_proba = self._availability_base_model.predict_proba(model_features)
                    if raw_proba.shape[1] > 1:
                        prob_unavailable = float(raw_proba[0, 1])
                    else:
                        prob_unavailable = float(raw_proba[0, 0])

                # Apply Platt calibration if available
                if self._availability_calibrator is not None:
                    logits = np.log(
                        np.clip(prob_unavailable, 1e-6, 1 - 1e-6)
                        / (1 - np.clip(prob_unavailable, 1e-6, 1 - 1e-6))
                    )
                    calibrated_proba = self._availability_calibrator.predict_proba(
                        logits.reshape(1, -1)
                    )
                    prob_unavailable = float(calibrated_proba[0, 1])

                prob_unavailable = float(np.clip(prob_unavailable, 1e-6, 1 - 1e-6))
                confidence = 0.85
                model_version = (
                    self._availability_bundle.model_id if self._availability_bundle else "unknown"
                )

                # Apply thresholds for three-state decision
                available_threshold = self._availability_thresholds.get(
                    "available_max_probability_unavailable", 0.1674
                )
                unavailable_threshold = self._availability_thresholds.get(
                    "unavailable_min_probability_unavailable", 0.4385
                )

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
                    Booking.status.in_(
                        [BookingStatus.CHECKED_IN.value, BookingStatus.CHARGING.value]
                    ),
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
            confidence=confidence,
        )

        return {
            "probability_unavailable": prob_unavailable,
            "availability_decision": availability_decision,
            "congestion_level": congestion,
            "confidence": confidence,
            "model_version": model_version,
        }

    async def predict_wait_time(
        self,
        db: AsyncSession,
        charger_id: UUID,
        port_id: UUID,
        model: Any | None = None,
        *,
        features_df: Any | None = None,
        target_time: datetime | None = None,
        availability_prediction: dict | None = None,
        demand_prediction: dict | None = None,
    ) -> dict:
        """
        Model 3: expected queue wait at the driver's ETA.

        A promoted hurdle-model artifact is used when present. Until that
        artifact is packaged, the fallback uses the same synthetic-world
        causal features instead of pretending availability probability alone
        is a wait-time model.
        """
        features_df = (
            features_df
            if features_df is not None
            else await build_availability_features(
                db,
                charger_id,
                port_id,
                target_time=target_time,
            )
        )
        predictor = self._waiting_model if self._waiting_model is not None else model
        model_version = "synthetic-queue-fallback-v1"
        confidence = 0.55
        nonzero_probability = 0.0
        wait_minutes = 0.0
        if predictor is not None:
            try:
                frame = features_df.copy()
                waiting_defaults = {
                    "prior_wait_observation_count": 0.0,
                    "prior_mean_queue_wait_minutes": np.nan,
                    "prior_positive_wait_rate": np.nan,
                    "waiting_history_missing": 1.0,
                }
                for feature, value in waiting_defaults.items():
                    if feature not in frame.columns:
                        frame[feature] = value
                model_features = self._align_features(frame, self._waiting_features)
                wait_minutes = float(max(predictor.predict(model_features)[0], 0.0))
                if hasattr(predictor, "predict_nonzero_probability"):
                    nonzero_probability = float(
                        np.clip(predictor.predict_nonzero_probability(model_features)[0], 0.0, 1.0)
                    )
                model_version = (
                    self._waiting_bundle.model_id if self._waiting_bundle else "supplied"
                )
                confidence = 0.82
            except Exception as exc:
                logger.error("[MLAdapter] Waiting-time prediction failed: %s", exc)

        if model_version == "synthetic-queue-fallback-v1":
            row = features_df.iloc[0]
            availability_prediction = availability_prediction or await self.predict_availability(
                db,
                charger_id,
                port_id,
                features_df=features_df,
                target_time=target_time,
            )
            probability_unavailable = float(
                availability_prediction.get("probability_unavailable", 0.5)
            )
            expected_demand = float((demand_prediction or {}).get("expected_demand", 1.0))
            port_count = max(float(row.get("site_port_count", 1.0)), 1.0)
            booking_load = float(row.get("known_bookings_near_target", 0.0)) / port_count
            session_load = float(row.get("active_session_count", 0.0)) / port_count
            overflow_demand = max(0.0, expected_demand - port_count) / port_count
            wait_minutes = min(
                120.0,
                28.0 * booking_load
                + 22.0 * session_load
                + 18.0 * overflow_demand
                + 16.0 * probability_unavailable,
            )
            nonzero_probability = min(
                1.0,
                0.55 * probability_unavailable
                + 0.25 * min(booking_load + session_load, 1.0)
                + 0.20 * min(overflow_demand, 1.0),
            )

        await MLAdapter.log_prediction(
            db=db,
            entity_id=port_id,
            target_type="port",
            model_version=model_version,
            prediction_type="expected_wait_minutes",
            value=wait_minutes,
            confidence=confidence,
        )
        return {
            "wait_minutes": wait_minutes,
            "nonzero_wait_probability": nonzero_probability,
            "congestion_level": "LOW"
            if wait_minutes < 5
            else "MEDIUM"
            if wait_minutes < 20
            else "HIGH",
            "confidence": confidence,
            "model_version": model_version,
        }

    async def predict_reliability(
        self,
        db: AsyncSession,
        charger_id: UUID,
        port_id: UUID,
        *,
        features_df: Any | None = None,
        target_time: datetime | None = None,
        fallback_score: float = 0.5,
    ) -> dict:
        """Model 4: probability that the charger works when the driver arrives."""
        features_df = (
            features_df
            if features_df is not None
            else await build_availability_features(
                db,
                charger_id,
                port_id,
                target_time=target_time,
            )
        )
        probability_reliable = min(max(fallback_score, 0.0), 1.0)
        model_version = "synthetic-reliability-fallback-v1"
        confidence = 0.55
        decision = "unknown"

        if self._reliability_base_model is not None:
            try:
                model_features = self._align_features(
                    features_df,
                    self._reliability_features,
                )
                raw_probability = float(
                    self._reliability_base_model.predict_proba(model_features)[0, 1]
                )
                probability_unreliable = float(np.clip(raw_probability, 1e-6, 1 - 1e-6))
                if self._reliability_calibrator is not None:
                    logit = np.log(probability_unreliable / (1 - probability_unreliable))
                    probability_unreliable = float(
                        self._reliability_calibrator.predict_proba(np.asarray([[logit]]))[0, 1]
                    )
                probability_reliable = 1.0 - probability_unreliable
                low = self._reliability_thresholds.get("reliable_max_probability_unreliable", 0.2)
                high = self._reliability_thresholds.get(
                    "unreliable_min_probability_unreliable", 0.5
                )
                decision = (
                    "reliable"
                    if probability_unreliable <= low
                    else "unreliable"
                    if probability_unreliable >= high
                    else "unknown"
                )
                model_version = self._reliability_bundle.model_id
                confidence = 0.84 if decision != "unknown" else 0.65
            except Exception as exc:
                logger.error("[MLAdapter] Reliability prediction failed: %s", exc)

        if model_version == "synthetic-reliability-fallback-v1":
            row = features_df.iloc[0]
            port_history = float(row.get("smoothed_reliability", fallback_score))
            charger_history = float(row.get("smoothed_charger_reliability", fallback_score))
            status_confidence = float(row.get("latest_status_confidence", 0.5))
            stale_penalty = 0.08 if float(row.get("status_expired", 0.0)) else 0.0
            probability_reliable = min(
                max(
                    0.45 * probability_reliable
                    + 0.30 * port_history
                    + 0.20 * charger_history
                    + 0.05 * status_confidence
                    - stale_penalty,
                    0.0,
                ),
                1.0,
            )
            evidence = float(row.get("reliability_evidence_count", 0.0))
            confidence = min(0.75, 0.5 + evidence / 100.0)
            decision = (
                "reliable"
                if probability_reliable >= 0.8
                else "unreliable"
                if probability_reliable < 0.5
                else "unknown"
            )

        await MLAdapter.log_prediction(
            db=db,
            entity_id=port_id,
            target_type="port",
            model_version=model_version,
            prediction_type="reliability_probability",
            value=probability_reliable,
            confidence=confidence,
        )
        return {
            "probability_reliable": probability_reliable,
            "decision": decision,
            "confidence": confidence,
            "model_version": model_version,
        }


# Singleton instance - models loaded at startup via main.py lifespan
ml_adapter = MLAdapter()
