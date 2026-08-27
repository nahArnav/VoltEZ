from datetime import date, time
import uuid

from sqlalchemy import Boolean, CheckConstraint, Date, ForeignKey, Integer, Time
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class BusinessHours(Base):
    __tablename__ = "business_hours"
    __table_args__ = (
    CheckConstraint(
        "day_of_week BETWEEN 0 AND 6",
        name="ck_business_hours_day_of_week",
    ),
    CheckConstraint(
        "close_local_time > open_local_time",
        name="ck_business_hours_time_order",
    ),
    CheckConstraint(
        "effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from",
        name="ck_business_hours_effective_date_order",
    ),
    {"schema": "app"},
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.businesses.id"),
        nullable=False,
    )

    day_of_week: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    open_local_time: Mapped[time] = mapped_column(
        Time,
        nullable=False,
    )

    close_local_time: Mapped[time] = mapped_column(
        Time,
        nullable=False,
    )

    is_closed: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
    )

    effective_from: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
    )

    effective_to: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
    )