"""Validated, application-facing inference contracts."""

from voltez_ml.serving.availability import (
    AvailabilityFeatureContract,
    AvailabilityFeatureRequest,
    AvailabilityInputError,
    AvailabilityPredictionResponse,
    AvailabilityPredictor,
    build_availability_feature_contract,
)
from voltez_ml.serving.demand import (
    DemandFeatureContract,
    DemandFeatureRequest,
    DemandInputError,
    DemandPredictionResponse,
    DemandPredictor,
    build_demand_feature_contract,
)

__all__ = [
    "AvailabilityFeatureContract",
    "AvailabilityFeatureRequest",
    "AvailabilityInputError",
    "AvailabilityPredictionResponse",
    "AvailabilityPredictor",
    "DemandFeatureContract",
    "DemandFeatureRequest",
    "DemandInputError",
    "DemandPredictionResponse",
    "DemandPredictor",
    "build_availability_feature_contract",
    "build_demand_feature_contract",
]
