from enum import StrEnum


class UserRole(StrEnum):
    DRIVER = "driver"
    OWNER = "owner"
    ADMIN = "admin"


class BookingStatus(StrEnum):
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    COMPLETED = "completed"
    IN_PROGRESS = "in_progress"
    PENDING = "pending"
    HELD = "held"
    EXPIRED = "expired"
    CHECKED_IN = "checked_in"
    CHARGING = "charging"


class ChargerStatus(StrEnum):
    AVAILABLE = "available"
    IN_USE = "in_use"
    MAINTENANCE = "maintenance"
    OFFLINE = "offline"
