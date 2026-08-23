import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, Boolean, DateTime, ForeignKey, Integer, Numeric, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class ChargerSearchResult(Base):
    __tablename__ = "charger_search_results"
    __table_args__ = (
    CheckConstraint(
        "rank_position > 0",
        name="ck_charger_search_results_rank_positive",
    ),
    CheckConstraint(
        "distance_km IS NULL OR distance_km >= 0",
        name="ck_charger_search_results_distance_nonnegative",
    ),
    CheckConstraint(
        "estimated_wait_minutes IS NULL OR estimated_wait_minutes >= 0",
        name="ck_charger_search_results_wait_nonnegative",
    ),
    CheckConstraint(
        "estimated_price IS NULL OR estimated_price >= 0",
        name="ck_charger_search_results_price_nonnegative",
    ),
    CheckConstraint(
        "compatibility_score IS NULL OR "
        "(compatibility_score >= 0 AND compatibility_score <= 1)",
        name="ck_charger_search_results_compatibility_score_range",
    ),
    CheckConstraint(
        "availability_score IS NULL OR "
        "(availability_score >= 0 AND availability_score <= 1)",
        name="ck_charger_search_results_availability_score_range",
    ),
    CheckConstraint(
        "final_score IS NULL OR "
        "(final_score >= 0 AND final_score <= 1)",
        name="ck_charger_search_results_final_score_range",
    ),
    {"schema": "app"},
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    search_event_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.charger_search_events.id"),
        nullable=False,
    )

    charger_port_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.charger_ports.id"),
        nullable=False,
    )

    rank_position: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    distance_km: Mapped[float | None] = mapped_column(
        Numeric(8, 2),
        nullable=True,
    )

    estimated_wait_minutes: Mapped[float | None] = mapped_column(
        Numeric(8, 2),
        nullable=True,
    )

    estimated_price: Mapped[float | None] = mapped_column(
        Numeric(10, 2),
        nullable=True,
    )

    compatibility_score: Mapped[float | None] = mapped_column(
        Numeric(5, 4),
        nullable=True,
    )

    availability_score: Mapped[float | None] = mapped_column(
        Numeric(5, 4),
        nullable=True,
    )

    final_score: Mapped[float | None] = mapped_column(
        Numeric(5, 4),
        nullable=True,
    )

    selected: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )