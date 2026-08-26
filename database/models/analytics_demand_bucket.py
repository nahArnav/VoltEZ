import uuid
from datetime import datetime

from sqlalchemy import DateTime, Float, Integer, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class DemandBucket(Base):
    """Aggregated demand metrics per zone per time bucket for analytics dashboards."""

    __tablename__ = "analytics_demand_buckets"
    __table_args__ = {"schema": "app"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    zone_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("app.zones.id"), nullable=False
    )

    bucket_start: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )

    bucket_end: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )

    request_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )

    booking_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )

    avg_occupancy: Mapped[float] = mapped_column(
        Float, nullable=False, default=0.0
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
