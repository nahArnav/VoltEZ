import math
from typing import List, Any
from sqlalchemy.ext.asyncio import AsyncSession
from app.schemas.recommendation import RecommendationRequest, RecommendationResult, RecommendationResponse
from app.services.charger import charger_service
from app.repositories.vehicle import vehicle_repo
from fastapi import HTTPException
from app.ml.adapters import ml_adapter


def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0  # Earth radius in kilometers
    dLat = math.radians(lat2 - lat1)
    dLon = math.radians(lon2 - lon1)
    a = math.sin(dLat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dLon / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


def get_float(obj: Any, attr: str, default: float = 0.0) -> float:
    """Helper to safely extract float values from SQLAlchemy ORM instances for Pyright."""
    val = getattr(obj, attr, None)
    return float(val) if val is not None else default

class RecommendationService:

    @staticmethod
    async def get_recommendations(
        db: AsyncSession,
        req: RecommendationRequest,
        availability_model: Any = None
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
            if str(charger.status) != "available":
                continue

            # Safely get dynamically attached lat/lon
            charger_lat = get_float(charger, "latitude")
            charger_lon = get_float(charger, "longitude")

            # Calculate Distance
            dist_km = _haversine(req.latitude, req.longitude, charger_lat, charger_lon)
            
            # Reachability Math - Route-Energy Physics Implementation
            veh_battery = get_float(vehicle, "battery_kwh")
            usable_energy_kwh = veh_battery * max(0.0, req.current_soc - req.reserve_soc)
            
            veh_mass = 2000.0 # Default mass
            crr = 0.015 # Rolling resistance
            g = 9.81
            drag_area = 2.5
            rho = 1.2
            speed_mps = 60 * 1000 / 3600 # 60 km/h
            
            rolling_energy_kwh = crr * veh_mass * g * (dist_km * 1000) / 3.6e6
            drag_energy_kwh = 0.5 * rho * drag_area * (speed_mps ** 2) * (dist_km * 1000) / 3.6e6
            total_route_energy = rolling_energy_kwh + drag_energy_kwh
            
            reachable = bool(usable_energy_kwh >= total_route_energy)
            reachable_km = dist_km if reachable else 0.0

            # Charge-time Math
            required_energy_kwh = veh_battery * max(0.0, req.target_soc - req.current_soc)
            
            # Find best port power
            best_port_kw = 0.0
            best_port_id = None
            for port in charger.ports:
                if not port.is_active:
                    continue
                kw = get_float(port, "max_power_kw")
                if kw > best_port_kw:
                    best_port_kw = kw
                    best_port_id = port.id
            
            if best_port_kw == 0.0 or not best_port_id:
                continue  # No compatible/available ports
            
            is_dc = best_port_kw > 22.0
            veh_max_dc = get_float(vehicle, "max_dc_kw")
            veh_max_ac = get_float(vehicle, "max_ac_kw")
            car_limit = veh_max_dc if is_dc and veh_max_dc > 0 else (veh_max_ac if veh_max_ac > 0 else best_port_kw)
                
            effective_power_kw = min(car_limit, best_port_kw)
            
            ideal_time_hr = required_energy_kwh / effective_power_kw if effective_power_kw > 0 else 99.0
            estimated_charge_min = ideal_time_hr * 60.0 * 1.2  # 1.2 is a taper factor

            # Cost Math (fixed $15/kWh rate instead of non-existent base_price)
            charger_base_price = 15.0
            estimated_cost = required_energy_kwh * charger_base_price
            
            # Wait time (ML Model 2)
            rel_score = get_float(charger, "reliability_score", 0.5)
            wait_prediction = await ml_adapter.predict_wait_time(
                db, 
                charger_id=charger.id,
                port_id=best_port_id,
                model=availability_model
            )
            predicted_wait_min = wait_prediction["wait_minutes"]

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
