"""merge migration heads and align the live booking contract

Revision ID: 20260826a001
Revises: 27e2cea710ae, 314159265358
Create Date: 2026-08-26 14:40:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "20260826a001"
down_revision: tuple[str, str] = ("27e2cea710ae", "314159265358")
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Join both histories and add fields required by the booking service."""
    op.add_column(
        "bookings",
        sa.Column("hold_expires_at", sa.DateTime(timezone=True), nullable=True),
        schema="app",
    )
    op.create_foreign_key(
        "fk_booking_events_booking_id",
        "booking_events",
        "bookings",
        ["booking_id"],
        ["id"],
        source_schema="app",
        referent_schema="app",
        ondelete="CASCADE",
    )
    op.create_index(
        "ix_booking_events_booking_id_created_at",
        "booking_events",
        ["booking_id", "created_at"],
        schema="app",
    )


def downgrade() -> None:
    op.drop_index(
        "ix_booking_events_booking_id_created_at",
        table_name="booking_events",
        schema="app",
    )
    op.drop_constraint(
        "fk_booking_events_booking_id",
        "booking_events",
        schema="app",
        type_="foreignkey",
    )
    op.drop_column("bookings", "hold_expires_at", schema="app")
