import math
from typing import List
from sqlalchemy.ext.asyncio import AsyncSession
from app.schemas.recommendation import RecommendationRequest, RecommendationResult, RecommendationResponse
from app.services.charger import charger_service
from app.repositories.vehicle import vehicle_repo
from fastapi import HTTPException


def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0  # Earth radius in kilometers
    dLat = math.radians(lat2 - lat1)
    dLon = math.radians(lon2 - lon1)
    a = math.sin(dLat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dLon / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


from typing import Any

def get_float(obj: Any, attr: str, default: float = 0.0) -> float:
    """Helper to safely extract float values from SQLAlchemy ORM instances for Pyright."""
    val = getattr(obj, attr, None)
    return float(val) if val is not None else default

class RecommendationService:

    @staticmethod
    async def get_recommendations(
        db: AsyncSession,
        req: RecommendationRequest
    ) -> RecommendationResponse:
        
        # 1. Fetch vehicle
        vehicle = await vehicle_repo.get(db, id=req.vehicle_id)
        if not vehicle:
            raise HTTPException(status_code=404, detail="Vehicle not found")

        # 2. Get Candidates (spatial search)
        candidates = await charger_service.get_nearby_chargers(
            db=db,
            latitude=req.latitude,
            longitude=req.longitude,
            radius_meters=int(req.radius_meters)
        )

        results = []
        from app.schemas.charger import ChargerResponse

        # 3. Process each candidate
        for charger in candidates:
            # We hard-filter inactive chargers
            if str(charger.status) != "active":
                continue

            # Safely get dynamically attached lat/lon
            charger_lat = get_float(charger, "latitude")
            charger_lon = get_float(charger, "longitude")

            # Calculate Distance
            dist_km = _haversine(req.latitude, req.longitude, charger_lat, charger_lon)
            
            # Reachability Math
            veh_battery = get_float(vehicle, "battery_kwh")
            usable_energy_kwh = veh_battery * max(0.0, req.current_soc - req.reserve_soc)
            
            # Default efficiency to 5 km/kWh if estimated_range_km is missing
            est_range = get_float(vehicle, "estimated_range_km", 0.0)
            efficiency = (est_range / veh_battery) if est_range > 0 else 5.0
            reachable_km = usable_energy_kwh * efficiency
            
            reachable = bool(reachable_km >= dist_km)

            # Charge-time Math
            required_energy_kwh = veh_battery * max(0.0, req.target_soc - req.current_soc)
            
            # Find best port power
            best_port_kw = 0.0
            for port in charger.ports:
                if str(port.status) != "available":
                    continue
                # Assuming vehicle.connector_types is a list of strings
                if str(port.connector_type) in (vehicle.connector_types or []):
                    best_port_kw = max(best_port_kw, get_float(port, "max_power_kw"))
            
            if best_port_kw == 0.0:
                continue  # No compatible/available ports
            
            is_dc = best_port_kw > 22.0
            veh_max_dc = get_float(vehicle, "max_dc_kw")
            veh_max_ac = get_float(vehicle, "max_ac_kw")
            car_limit = veh_max_dc if is_dc and veh_max_dc > 0 else (veh_max_ac if veh_max_ac > 0 else best_port_kw)
                
            effective_power_kw = min(car_limit, best_port_kw)
            
            ideal_time_hr = required_energy_kwh / effective_power_kw if effective_power_kw > 0 else 99.0
            estimated_charge_min = ideal_time_hr * 60.0 * 1.2  # 1.2 is a taper factor

            # Cost Math
            charger_base_price = get_float(charger, "base_price")
            estimated_cost = required_energy_kwh * charger_base_price
            
            # Wait time (Placeholder)
            rel_score = get_float(charger, "reliability_score", 0.5)
            predicted_wait_min = 10.0 * (1.0 - rel_score)

            # Ranking Formula
            score = 1000.0 - (
                (5.0 * dist_km) + 
                (1.0 * estimated_charge_min) + 
                (0.5 * (estimated_cost / 10.0)) +
                (2.0 * predicted_wait_min)
            ) + (50.0 * rel_score)
            
            if not reachable:
                score -= 10000.0

            results.append(
                RecommendationResult(
                    charger=ChargerResponse.model_validate(charger),
                    reachable=reachable,
                    estimated_reach_distance_km=float(round(reachable_km, 2)),
                    distance_to_charger_km=float(round(dist_km, 2)),
                    estimated_charge_minutes=float(round(estimated_charge_min, 1)),
                    estimated_cost=float(round(estimated_cost, 2)),
                    ranking_score=float(round(score, 2))
                )
            )

        # Sort by ranking score descending
        results.sort(key=lambda x: x.ranking_score, reverse=True)

        return RecommendationResponse(recommendations=results)

recommendation_service = RecommendationService()
