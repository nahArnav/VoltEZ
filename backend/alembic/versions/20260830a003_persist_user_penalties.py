"""persist driver cancellation penalties and suspensions"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260830a003"
down_revision: str | Sequence[str] | None = "20260830a002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("cancellation_strikes", sa.Integer(), nullable=False, server_default="0"),
        schema="app",
    )
    op.add_column(
        "users",
        sa.Column("penalty_points", sa.Integer(), nullable=False, server_default="0"),
        schema="app",
    )
    op.add_column(
        "users",
        sa.Column("suspended_until", sa.DateTime(timezone=True), nullable=True),
        schema="app",
    )
    op.create_check_constraint(
        "ck_users_cancellation_strikes",
        "users",
        "cancellation_strikes >= 0",
        schema="app",
    )
    op.create_check_constraint(
        "ck_users_penalty_points",
        "users",
        "penalty_points >= 0",
        schema="app",
    )
    op.alter_column("users", "cancellation_strikes", server_default=None, schema="app")
    op.alter_column("users", "penalty_points", server_default=None, schema="app")


def downgrade() -> None:
    op.drop_constraint("ck_users_penalty_points", "users", schema="app", type_="check")
    op.drop_constraint("ck_users_cancellation_strikes", "users", schema="app", type_="check")
    op.drop_column("users", "suspended_until", schema="app")
    op.drop_column("users", "penalty_points", schema="app")
    op.drop_column("users", "cancellation_strikes", schema="app")
