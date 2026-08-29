"""store per-charger tariffs for truthful estimates and billing

Revision ID: 20260829a001
Revises: 20260826a006
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260829a001"
down_revision: str | Sequence[str] | None = "20260826a006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "chargers",
        sa.Column("price_per_kwh", sa.Numeric(10, 2), nullable=False, server_default="15.00"),
        schema="app",
    )
    op.create_check_constraint(
        "ck_chargers_price_per_kwh_positive",
        "chargers",
        "price_per_kwh > 0",
        schema="app",
    )
    op.alter_column("chargers", "price_per_kwh", server_default=None, schema="app")


def downgrade() -> None:
    op.drop_constraint(
        "ck_chargers_price_per_kwh_positive", "chargers", schema="app", type_="check"
    )
    op.drop_column("chargers", "price_per_kwh", schema="app")
