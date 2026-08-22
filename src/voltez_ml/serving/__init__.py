"""Validated, application-facing inference contracts."""

from voltez_ml.serving.demand import (
    DemandFeatureContract,
    DemandFeatureRequest,
    DemandInputError,
    DemandPredictionResponse,
    DemandPredictor,
    build_demand_feature_contract,
)

__all__ = [
    "DemandFeatureContract",
    "DemandFeatureRequest",
    "DemandInputError",
    "DemandPredictionResponse",
    "DemandPredictor",
    "build_demand_feature_contract",
]
