"""record charger access policy for serving and availability features"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260830a002"
down_revision: str | Sequence[str] | None = "20260830a001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "chargers",
        sa.Column("access_type", sa.String(length=20), nullable=False, server_default="public"),
        schema="app",
    )
    op.create_check_constraint(
        "ck_charger_access_type",
        "chargers",
        "access_type IN ('public', 'controlled', 'customer_only')",
        schema="app",
    )
    op.alter_column("chargers", "access_type", server_default=None, schema="app")


def downgrade() -> None:
    op.drop_constraint("ck_charger_access_type", "chargers", schema="app", type_="check")
    op.drop_column("chargers", "access_type", schema="app")
