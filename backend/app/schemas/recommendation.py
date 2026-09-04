from typing import Literal, cast
from uuid import UUID

from pydantic import BaseModel, Field, model_validator

from app.schemas.charger import ChargerResponse


class RecommendationRequest(BaseModel):
    latitude: float = Field(..., description="Current latitude of the user/vehicle")
    longitude: float = Field(..., description="Current longitude of the user/vehicle")
    destination_latitude: float | None = Field(
        None,
        description="Optional destination latitude for detour-aware ranking",
        ge=-90.0,
        le=90.0,
    )
    destination_longitude: float | None = Field(
        None,
        description="Optional destination longitude for detour-aware ranking",
        ge=-180.0,
        le=180.0,
    )
    radius_meters: float = Field(5000.0, description="Search radius in meters")
    vehicle_id: UUID = Field(..., description="ID of the vehicle to charge")
    current_soc: float = Field(
        ..., description="Current State of Charge (0.0 to 1.0)", ge=0.0, le=1.0
    )
    target_soc: float = Field(
        ..., description="Target State of Charge (0.0 to 1.0)", ge=0.0, le=1.0
    )
    reserve_soc: float = Field(
        0.1, description="Desired arrival reserve SOC (0.0 to 1.0)", ge=0.0, le=1.0
    )
    preferences: dict | None = Field(
        None, description="Optional user preferences (e.g. prioritize_cost, prioritize_speed)"
    )
    route_distance_km: float | None = Field(
        None,
        ge=0.0,
        description="Driving distance for the direct origin-to-destination route",
    )
    route_duration_minutes: int | None = Field(
        None,
        ge=0,
        description="Driving ETA for the direct origin-to-destination route",
    )
    route_polyline: str | None = Field(
        None,
        max_length=100000,
        description="Encoded direct-route polyline used for charger corridor filtering",
    )

    @model_validator(mode="after")
    def validate_destination_pair(self):
        if (self.destination_latitude is None) != (self.destination_longitude is None):
            raise ValueError(
                "destination_latitude and destination_longitude must be provided together"
            )
        if self.target_soc <= self.reserve_soc:
            raise ValueError("target_soc must be greater than reserve_soc")
        return self

    @property
    def optimization_mode(self) -> Literal["fastest", "cheapest", "balanced", "reliable"]:
        requested = str((self.preferences or {}).get("mode", "balanced")).lower()
        if requested not in {"fastest", "cheapest", "balanced", "reliable"}:
            requested = "balanced"
        return cast(
            Literal["fastest", "cheapest", "balanced", "reliable"],
            requested,
        )


class RouteWaypoint(BaseModel):
    charger_id: UUID
    name: str
    latitude: float
    longitude: float


class RoutePlan(BaseModel):
    mode: Literal["fastest", "cheapest", "balanced", "reliable"]
    algorithm: Literal["astar"] = "astar"
    reachable: bool
    requires_charging: bool
    waypoints: list[RouteWaypoint] = Field(default_factory=list)
    distance_km: float = Field(ge=0.0)
    drive_minutes: float = Field(ge=0.0)
    charging_minutes: float = Field(ge=0.0)
    waiting_minutes: float = Field(ge=0.0)
    total_eta_minutes: float = Field(ge=0.0)
    estimated_cost: float = Field(ge=0.0)
    reliability_probability: float = Field(ge=0.0, le=1.0)
    availability_probability: float = Field(ge=0.0, le=1.0)
    expected_demand: float = Field(ge=0.0)
    polyline: str = ""
    navigation_provider: Literal["google_routes", "estimated", "unavailable"]
    model_sources: dict[str, str] = Field(default_factory=dict)


class RecommendationResult(BaseModel):
    charger: ChargerResponse
    reachable: bool = Field(
        ..., description="Whether the vehicle has enough battery to reach this charger"
    )
    estimated_reach_distance_km: float = Field(
        ..., description="Estimated distance the car can travel with current SOC"
    )
    distance_to_charger_km: float = Field(..., description="Straight-line distance to charger")
    estimated_charge_minutes: float = Field(
        ..., description="Estimated time required to reach target SOC"
    )
    estimated_cost: float = Field(..., description="Estimated cost for the charging session")
    estimated_price_per_kwh: float | None = Field(
        None, description="Bounded dynamic tariff used for the estimate"
    )
    ranking_score: float = Field(
        ..., description="Computed score used to sort recommendations (higher is better)"
    )
    estimated_detour_km: float = Field(
        0.0,
        description="Additional distance versus the direct origin-to-destination route",
        ge=0.0,
    )
    predicted_wait_minutes: float = Field(default=0.0, ge=0.0)
    probability_unavailable: float = Field(default=0.0, ge=0.0, le=1.0)
    predicted_demand: float = Field(default=0.0, ge=0.0)
    predicted_reliability: float = Field(default=0.5, ge=0.0, le=1.0)
    estimated_total_trip_minutes: float = Field(default=0.0, ge=0.0)
    route_feasible: bool = True
    optimization_mode: Literal["fastest", "cheapest", "balanced", "reliable"] = "balanced"
    model_sources: dict[str, str] = Field(default_factory=dict)


class RecommendationResponse(BaseModel):
    recommendations: list[RecommendationResult]
    route_plan: RoutePlan | None = None
