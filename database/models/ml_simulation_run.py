import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class SimulationRun(Base):
    """Records of ML simulation/rehearsal runs for experiment tracking."""

    __tablename__ = "simulation_runs"
    __table_args__ = {"schema": "app"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    scenario_name: Mapped[str] = mapped_column(
        String(100), nullable=False
    )

    parameters: Mapped[dict | None] = mapped_column(
        JSONB, nullable=True
    )

    results: Mapped[dict | None] = mapped_column(
        JSONB, nullable=True
    )

    executed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
