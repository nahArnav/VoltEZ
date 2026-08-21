from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass

from database.models.user import User  # noqa: E402,F401
from database.models.connector import ConnectorType  # noqa: E402,F401
from database.models.vehicle import Vehicle  # noqa: E402,F401
from database.models.vehicle_connector import VehicleConnector  # noqa: E402,F401