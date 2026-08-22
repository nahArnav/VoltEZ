from typing import List
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status

from app.models.charger import Charger
from app.schemas.charger import ChargerCreate
from app.repositories.business import business_repo
from app.repositories.charger import charger_repo

class ChargerService:
    
    @staticmethod
    async def create_charger(db: AsyncSession, business_id: int, charger_in: ChargerCreate) -> Charger:
        """Business logic for creating a new charger with spatial data."""
        
        # 1. Ensure the business (location) actually exists first
        business = await business_repo.get(db, id=business_id)
        if not business:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, 
                detail="Business location not found."
            )
            
        # 2. Extract incoming JSON data
        charger_data = charger_in.model_dump(exclude_unset=True)
        charger_data["business_id"] = business_id
        
        # 3. Format coordinates for PostGIS (WKT format: POINT(Longitude Latitude))
        # Important: Maps usually say "Lat, Long", but PostGIS requires "Long, Lat" (X, Y)
        lon = charger_data.pop("longitude")
        lat = charger_data.pop("latitude")
        charger_data["location"] = f"SRID=4326;POINT({lon} {lat})"
        
        # 4. Save to the database
        db_charger = Charger(**charger_data)
        db.add(db_charger)
        await db.commit()
        await db.refresh(db_charger)
        
        return db_charger

    @staticmethod
    async def get_nearby_chargers(
        db: AsyncSession, 
        latitude: float, 
        longitude: float, 
        radius_meters: int = 5000
    ) -> List[Charger]:
        """
        Find all chargers within a given radius using highly optimized PostGIS indexing.
        """
        # Create a PostGIS-compatible geographic point for the driver's current location
        driver_location = func.ST_GeographyFromText(f"POINT({longitude} {latitude})")
        
        # Use ST_DWithin to check if the distance between the charger's coordinates 
        # and the driver's location is less than or equal to the radius.
        query = select(Charger).where(
            func.ST_DWithin(Charger.location, driver_location, radius_meters)
        )
        
        result = await db.execute(query)
        return list(result.scalars().all())

charger_service = ChargerService()