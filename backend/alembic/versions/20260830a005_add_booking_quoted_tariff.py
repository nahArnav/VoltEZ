"""store the server-calculated tariff agreed at booking time"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260830a005"
down_revision: str | Sequence[str] | None = "20260830a004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "bookings",
        sa.Column("quoted_price_per_kwh", sa.Numeric(precision=10, scale=2), nullable=True),
        schema="app",
    )


def downgrade() -> None:
    op.drop_column("bookings", "quoted_price_per_kwh", schema="app")
