"""limit booking overlap protection to active lifecycle states

Revision ID: 20260826a005
Revises: 20260826a004
Create Date: 2026-08-26 15:15:00.000000
"""

from collections.abc import Sequence

from alembic import op


revision: str = "20260826a005"
down_revision: str = "20260826a004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


ACTIVE_STATUSES = (
    "'pending', 'held', 'confirmed', 'checked_in', 'charging', 'in_progress'"
)


def upgrade() -> None:
    op.execute("ALTER TABLE app.bookings DROP CONSTRAINT excl_bookings_port_time")
    op.execute(
        f"""
        ALTER TABLE app.bookings
        ADD CONSTRAINT excl_bookings_port_time
        EXCLUDE USING gist (
            charger_port_id WITH =,
            tstzrange(start_at, end_at, '[)') WITH &&
        )
        WHERE (status IN ({ACTIVE_STATUSES}))
        """
    )


def downgrade() -> None:
    op.execute("ALTER TABLE app.bookings DROP CONSTRAINT excl_bookings_port_time")
    op.execute(
        """
        ALTER TABLE app.bookings
        ADD CONSTRAINT excl_bookings_port_time
        EXCLUDE USING gist (
            charger_port_id WITH =,
            tstzrange(start_at, end_at, '[)') WITH &&
        )
        """
    )
