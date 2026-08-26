import uuid
from datetime import datetime

from sqlalchemy import DateTime, Float, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class DemandBucket(Base):
    """Aggregated demand metrics per zone per time bucket for analytics dashboards."""

    __tablename__ = "demand_buckets"
    __table_args__ = {"schema": "analytics"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    zone_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )

    time_bucket: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    demand_score: Mapped[float] = mapped_column(Float, nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
