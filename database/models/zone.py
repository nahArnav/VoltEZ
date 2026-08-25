import uuid

from geoalchemy2 import Geometry
from sqlalchemy import Boolean, CheckConstraint, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class Zone(Base):
    __tablename__ = "zones"
    __table_args__ = (
    CheckConstraint(
        "btrim(city) <> ''",
        name="ck_zone_city_not_blank",
    ),
    CheckConstraint(
        "btrim(name) <> ''",
        name="ck_zone_name_not_blank",
    ),
    CheckConstraint(
        "h3_index IS NULL OR btrim(h3_index) <> ''",
        name="ck_zone_h3_index_not_blank",
    ),
    {"schema": "app"},
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    city: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    h3_index: Mapped[str | None] = mapped_column(
        String(30),
        unique=True,
    )

    boundary: Mapped[object | None] = mapped_column(
        Geometry(
            geometry_type="MULTIPOLYGON",
            srid=4326,
            spatial_index=True,
        )
    )

    centroid: Mapped[object | None] = mapped_column(
        Geometry(
            geometry_type="POINT",
            srid=4326,
            spatial_index=True,
        )
    )

    timezone: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        default="Asia/Kolkata",
    )

    active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
    )

    zone_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        default="commercial",
    )