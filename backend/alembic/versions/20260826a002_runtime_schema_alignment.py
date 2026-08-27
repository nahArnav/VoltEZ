"""align fields used by charger and charging-session services

Revision ID: 20260826a002
Revises: 20260826a001
Create Date: 2026-08-26 14:45:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260826a002"
down_revision: str = "20260826a001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "chargers",
        sa.Column(
            "reliability_score",
            sa.Numeric(precision=5, scale=2),
            nullable=False,
            server_default="100.0",
        ),
        schema="app",
    )
    op.add_column(
        "charging_sessions",
        sa.Column("booking_id", sa.UUID(), nullable=True),
        schema="app",
    )
    op.create_foreign_key(
        "fk_charging_sessions_booking_id",
        "charging_sessions",
        "bookings",
        ["booking_id"],
        ["id"],
        source_schema="app",
        referent_schema="app",
        ondelete="SET NULL",
    )
    op.create_index(
        "ix_charging_sessions_booking_id",
        "charging_sessions",
        ["booking_id"],
        schema="app",
    )


def downgrade() -> None:
    op.drop_index(
        "ix_charging_sessions_booking_id",
        table_name="charging_sessions",
        schema="app",
    )
    op.drop_constraint(
        "fk_charging_sessions_booking_id",
        "charging_sessions",
        schema="app",
        type_="foreignkey",
    )
    op.drop_column("charging_sessions", "booking_id", schema="app")
    op.drop_column("chargers", "reliability_score", schema="app")
