import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class FeatureSnapshot(Base):
    """Point-in-time ML feature snapshots for reproducibility and drift monitoring."""

    __tablename__ = "feature_snapshots"
    __table_args__ = {"schema": "app"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    target_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )

    target_type: Mapped[str] = mapped_column(
        String(50), nullable=False
    )

    features: Mapped[dict] = mapped_column(
        JSONB, nullable=False
    )

    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
