import uuid
from datetime import datetime

from geoalchemy2 import Geometry
from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, Integer, Numeric, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class ChargerSearchEvent(Base):
    __tablename__ = "charger_search_events"
    __table_args__ = (
        CheckConstraint(
            "requested_power_kw IS NULL OR requested_power_kw >= 0",
            name="ck_charger_search_event_power_nonnegative",
        ),
        CheckConstraint(
            "search_radius_km IS NULL OR search_radius_km >= 0",
            name="ck_charger_search_event_radius_nonnegative",
        ),
        CheckConstraint(
            "chargers_found >= 0",
            name="ck_charger_search_event_chargers_found_nonnegative",
        ),
        Index(
            "ix_charger_search_events_location",
            "search_location",
            postgresql_using="gist",
        ),
        Index(
            "idx_charger_search_events_search_location",
            "search_location",
            postgresql_using="gist",
        ),
        {"schema": "app"},
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.users.id"),
        nullable=False,
    )

    vehicle_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.vehicles.id"),
        nullable=True,
    )

    zone_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.zones.id"),
        nullable=True,
    )

    search_location: Mapped[object] = mapped_column(
        Geometry(
            geometry_type="POINT",
            srid=4326,
            spatial_index=False,
        ),
        nullable=False,
    )

    requested_connector_type_id: Mapped[int | None] = mapped_column(
        ForeignKey("app.connector_types.id"),
        nullable=True,
    )

    requested_power_kw: Mapped[float | None] = mapped_column(
        Numeric(8, 2),
        nullable=True,
    )

    search_radius_km: Mapped[float | None] = mapped_column(
        Numeric(8, 2),
        nullable=True,
    )

    chargers_found: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
