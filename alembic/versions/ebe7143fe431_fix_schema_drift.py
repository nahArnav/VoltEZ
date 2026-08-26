"""fix schema drift

Revision ID: ebe7143fe431
Revises: 20260826a006
Create Date: 2026-08-26 19:47:51.885509

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ebe7143fe431'
down_revision: Union[str, Sequence[str], None] = '20260826a006'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
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
    """Downgrade schema."""
    op.drop_index("ix_booking_events_booking_id_created_at", table_name="booking_events", schema="app")
    op.drop_constraint("fk_booking_events_booking_id", "booking_events", schema="app", type_="foreignkey")
