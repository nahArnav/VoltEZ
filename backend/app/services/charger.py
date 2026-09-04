import math
from uuid import UUID

from geoalchemy2 import Geometry as GeometryType
from geoalchemy2.types import Geography
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import NotFoundError
from app.repositories.business import business_repo
from app.schemas.charger import ChargerCreate
from database.models.charger import Charger
from database.models.charger_port import ChargerPort


class ChargerService:
    @staticmethod
    async def create_charger(
        db: AsyncSession, business_id: UUID, charger_in: ChargerCreate
    ) -> Charger:
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
        connector_type_id = charger_data.pop("connector_type_id", None)
        port_number = charger_data.pop("port_number", None)
        port_max_power_kw = charger_data.pop("port_max_power_kw", None)
        charger_data["location"] = f"SRID=4326;POINT({lon} {lat})"

        if (connector_type_id is None) != (port_number is None):
            raise ValueError("connector_type_id and port_number must be provided together")
        if connector_type_id is not None:
            # A port is useful only when the referenced connector is present;
            # the foreign-key error is converted into a clean validation error.
            from database.models.connector import ConnectorType

            connector = await db.get(ConnectorType, connector_type_id)
            if connector is None:
                raise ValueError("connector_type_id does not exist")

        # 4. Save to the database
        db_charger = Charger(**charger_data)
        db.add(db_charger)
        await db.flush()

        if connector_type_id is not None and port_number is not None:
            db.add(
                ChargerPort(
                    charger_id=db_charger.id,
                    connector_type_id=connector_type_id,
                    port_number=port_number,
                    max_power_kw=port_max_power_kw or charger_data["power_kw"],
                    is_active=True,
                )
            )

        # Commit the station and its first bookable port together. If either
        # insert fails, no half-registered charger is left behind.
        await db.commit()
        await db.refresh(db_charger, attribute_names=["ports"])

        # 5. Attach lat/lng for Pydantic serialization (ChargerResponse expects these fields)
        db_charger.latitude = lat
        db_charger.longitude = lon

        return db_charger

    @staticmethod
    async def get_charger(db: AsyncSession, charger_id: UUID) -> Charger | None:
        """Fetch one charger with ports and decoded map coordinates."""
        query = select(
            Charger,
            func.ST_Y(Charger.location.cast(GeometryType)).label("latitude"),
            func.ST_X(Charger.location.cast(GeometryType)).label("longitude"),
        ).where(Charger.id == charger_id)
        row = (await db.execute(query)).one_or_none()
        if row is None:
            return None
        charger, lat, lng = row
        charger.latitude = lat
        charger.longitude = lng
        return charger

    @staticmethod
    async def get_nearby_chargers(
        db: AsyncSession,
        latitude: float,
        longitude: float,
        radius_meters: int = 5000,
    ) -> list[Charger]:
        """
        Find all chargers within a given radius using PostGIS spatial indexing.

        Uses ST_DWithin for the spatial filter (hits the GiST index) and
        ST_X / ST_Y to extract coordinates for the API response.
        """
        driver_location = func.ST_GeographyFromText(f"POINT({longitude} {latitude})")

        # Query chargers with coordinates extracted in the same SELECT
        query = select(
            Charger,
            func.ST_Y(Charger.location.cast(GeometryType)).label("latitude"),
            func.ST_X(Charger.location.cast(GeometryType)).label("longitude"),
        ).where(func.ST_DWithin(Charger.location.cast(Geography), driver_location, radius_meters))

        result = await db.execute(query)
        rows = result.all()

        # Attach lat/lng onto each ORM object so Pydantic's from_attributes picks them up
        chargers = []
        for charger, lat, lng in rows:
            charger.latitude = lat
            charger.longitude = lng
            chargers.append(charger)

        return chargers

    @staticmethod
    async def get_route_candidate_chargers(
        db: AsyncSession,
        *,
        origin_latitude: float,
        origin_longitude: float,
        destination_latitude: float,
        destination_longitude: float,
        corridor_meters: float = 10000.0,
        limit: int = 128,
    ) -> list[Charger]:
        """Fetch chargers in the route bounding corridor before A* filtering.

        The database query uses the spatial index-friendly bounding envelope;
        the recommendation service then applies the finer polyline-distance
        filter. This scales better than loading every station and fixes the old
        origin-only radius search for location-to-location trips.
        """
        corridor_km = min(max(corridor_meters / 1000.0, 2.0), 25.0)
        middle_latitude = (origin_latitude + destination_latitude) / 2.0
        latitude_padding = corridor_km / 110.574
        longitude_scale = max(111.320 * math.cos(math.radians(middle_latitude)), 20.0)
        longitude_padding = corridor_km / longitude_scale
        envelope = func.ST_MakeEnvelope(
            min(origin_longitude, destination_longitude) - longitude_padding,
            min(origin_latitude, destination_latitude) - latitude_padding,
            max(origin_longitude, destination_longitude) + longitude_padding,
            max(origin_latitude, destination_latitude) + latitude_padding,
            4326,
        )
        query = (
            select(
                Charger,
                func.ST_Y(Charger.location.cast(GeometryType)).label("latitude"),
                func.ST_X(Charger.location.cast(GeometryType)).label("longitude"),
            )
            .options(selectinload(Charger.ports))
            .where(func.ST_Intersects(Charger.location, envelope))
            .limit(min(max(limit, 1), 500))
        )
        rows = (await db.execute(query)).all()
        chargers: list[Charger] = []
        for charger, latitude, longitude in rows:
            charger.latitude = latitude
            charger.longitude = longitude
            chargers.append(charger)
        return chargers


charger_service = ChargerService()
