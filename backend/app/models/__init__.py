"""
VoltEZ Database Models

Import all models here so Alembic can auto-detect them for migration generation.
"""

from app.models.base import Base
from app.models.user import User, UserRole
from app.models.vehicle import Vehicle
from app.models.business import Business
from app.models.charger import Charger
from app.models.charger_port import ChargerPort
from app.models.availability_window import AvailabilityWindow
from app.models.booking import Booking, BookingStatus
from app.models.booking_event import BookingEvent
from app.models.charging_session import ChargingSession
from app.models.payment import Payment
from app.models.charger_status_event import ChargerStatusEvent
from app.models.review import Review
from app.models.demand_history import DemandHistory
from app.models.ml_prediction import MLPrediction
from app.models.notification import Notification

__all__ = [
    "Base",
    "User",
    "UserRole",
    "Vehicle",
    "Business",
    "Charger",
    "ChargerPort",
    "AvailabilityWindow",
    "Booking",
    "BookingStatus",
    "BookingEvent",
    "ChargingSession",
    "Payment",
    "ChargerStatusEvent",
    "Review",
    "DemandHistory",
    "MLPrediction",
    "Notification",
]
