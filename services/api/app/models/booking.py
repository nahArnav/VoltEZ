from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, JSON, Index, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
from app.models.base import Base


class BookingStatus(str, enum.Enum):
    PENDING = "PENDING"
    HELD = "HELD"
    PAYMENT_PENDING = "PAYMENT_PENDING"
    CONFIRMED = "CONFIRMED"
    CANCELLED = "CANCELLED"
    EXPIRED = "EXPIRED"
    NO_SHOW = "NO_SHOW"
    CHECKED_IN = "CHECKED_IN"
    CHARGING = "CHARGING"
    COMPLETED = "COMPLETED"


class Booking(Base):
    __tablename__ = "bookings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    vehicle_id = Column(Integer, ForeignKey("vehicles.id", ondelete="SET NULL"), nullable=True, index=True)
    port_id = Column(Integer, ForeignKey("charger_ports.id", ondelete="CASCADE"), nullable=False)
    start_at = Column(DateTime(timezone=True), nullable=False)
    end_at = Column(DateTime(timezone=True), nullable=False)
    status = Column(Enum(BookingStatus), default=BookingStatus.PENDING, nullable=False, index=True)
    hold_expires_at = Column(DateTime(timezone=True), nullable=True)
    quote_snapshot = Column(JSON, nullable=True)  # Snapshot of pricing at booking time
    idempotency_key = Column(String, unique=True, nullable=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    user = relationship("User", back_populates="bookings")
    vehicle = relationship("Vehicle", back_populates="bookings")
    port = relationship("ChargerPort", back_populates="bookings")
    events = relationship("BookingEvent", back_populates="booking", lazy="selectin")
    session = relationship("ChargingSession", back_populates="booking", uselist=False, lazy="selectin")
    payment = relationship("Payment", back_populates="booking", uselist=False, lazy="selectin")

    __table_args__ = (
        # Index for overlap checks: find bookings for a port in a time range
        Index("idx_booking_port_time_status", "port_id", "start_at", "end_at", "status"),
    )
