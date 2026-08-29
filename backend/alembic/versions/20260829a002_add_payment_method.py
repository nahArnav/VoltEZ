"""record the selected payment method for each booking"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260829a002"
down_revision: str | Sequence[str] | None = "20260829a001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "payments",
        sa.Column("method", sa.String(length=20), nullable=False, server_default="upi"),
        schema="app",
    )
    op.create_check_constraint(
        "ck_payments_method", "payments", "method IN ('cash', 'card', 'upi')", schema="app"
    )
    op.alter_column("payments", "method", server_default=None, schema="app")


def downgrade() -> None:
    op.drop_constraint("ck_payments_method", "payments", schema="app", type_="check")
    op.drop_column("payments", "method", schema="app")
