from enum import Enum

class UserRole(str, Enum):
    DRIVER = "driver"
    OWNER = "owner"
    ADMIN = "admin"

class BookingStatus(str, Enum):
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    COMPLETED = "completed"
    IN_PROGRESS = "in_progress"
    PENDING = "pending"
    HELD = "held"
    EXPIRED = "expired"
    CHECKED_IN = "checked_in"
    CHARGING = "charging"

class ChargerStatus(str, Enum):
    AVAILABLE = "available"
    IN_USE = "in_use"
    MAINTENANCE = "maintenance"
    OFFLINE = "offline"
