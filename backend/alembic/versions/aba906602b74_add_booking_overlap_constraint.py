"""add booking overlap constraint

Revision ID: aba906602b74
Revises: d5a1c1a9ab4b
Create Date: 2026-08-24 00:28:16.336924

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "aba906602b74"
down_revision: str | Sequence[str] | None = "d5a1c1a9ab4b"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("""
        ALTER TABLE app.bookings
        ADD CONSTRAINT excl_bookings_port_time
        EXCLUDE USING gist (
            charger_port_id WITH =,
            tstzrange(start_at, end_at, '[)') WITH &&
        )
    """)


def downgrade() -> None:
    op.execute("""
        ALTER TABLE app.bookings
        DROP CONSTRAINT IF EXISTS excl_bookings_port_time
    """)
