from typing import List
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from geoalchemy2 import Geometry as GeometryType

from app.models.charger import Charger
from app.schemas.charger import ChargerCreate
from app.repositories.business import business_repo
from app.core.errors import NotFoundError


class ChargerService:

    @staticmethod
    async def create_charger(db: AsyncSession, business_id: int, charger_in: ChargerCreate) -> Charger:
        """Business logic for creating a new charger with spatial data."""

        # 1. Ensure the business (location) actually exists first
        business = await business_repo.get(db, id=business_id)
        if not business:
            raise NotFoundError(resource="Business")

        # 2. Extract incoming JSON data
        charger_data = charger_in.model_dump(exclude_unset=True)
        charger_data["business_id"] = business_id

        # 3. Format coordinates for PostGIS (WKT format with SRID)
        # Important: Maps say "Lat, Long", but PostGIS requires "Long, Lat" (X, Y)
        lon = charger_data.pop("longitude")
        lat = charger_data.pop("latitude")
        charger_data["location"] = f"SRID=4326;POINT({lon} {lat})"

        # 4. Save to the database
        db_charger = Charger(**charger_data)
        db.add(db_charger)
        await db.commit()
        await db.refresh(db_charger)

        # 5. Attach lat/lng for Pydantic serialization (ChargerResponse expects these fields)
        db_charger.latitude = lat
        db_charger.longitude = lon

        return db_charger

    @staticmethod
    async def get_nearby_chargers(
        db: AsyncSession,
        latitude: float,
        longitude: float,
        radius_meters: int = 5000,
    ) -> List[Charger]:
        """
        Find all chargers within a given radius using PostGIS spatial indexing.

        Uses ST_DWithin for the spatial filter (hits the GiST index) and
        ST_X / ST_Y to extract coordinates for the API response.
        """
        driver_location = func.ST_GeographyFromText(f"POINT({longitude} {latitude})")

        # Query chargers with coordinates extracted in the same SELECT
        query = (
            select(
                Charger,
                func.ST_Y(Charger.location.cast(GeometryType)).label("latitude"),
                func.ST_X(Charger.location.cast(GeometryType)).label("longitude"),
            )
            .where(func.ST_DWithin(Charger.location, driver_location, radius_meters))
        )

        result = await db.execute(query)
        rows = result.all()

        # Attach lat/lng onto each ORM object so Pydantic's from_attributes picks them up
        chargers = []
        for charger, lat, lng in rows:
            charger.latitude = lat
            charger.longitude = lng
            chargers.append(charger)

        return chargers


charger_service = ChargerService()