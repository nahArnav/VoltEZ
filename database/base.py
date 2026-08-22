from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass

from database.models.user import User  # noqa: E402,F401
from database.models.connector import ConnectorType  # noqa: E402,F401
from database.models.vehicle import Vehicle  # noqa: E402,F401
from database.models.vehicle_connector import VehicleConnector  # noqa: E402,F401
from database.models.zone import Zone  # noqa: E402,F401
from database.models.business import Business  # noqa: E402,F401
from database.models.business_hours import BusinessHours  # noqa: E402,F401
from database.models.business_hour_exception import BusinessHourException  # noqa: E402,F401
from database.models.amenity import Amenity  # noqa: E402,F401
from database.models.business_amenity import BusinessAmenity  # noqa: E402,F401