"""persist review issues and enforce one operational record per booking

Revision ID: 20260826a006
Revises: 20260826a005
Create Date: 2026-08-26 18:30:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260826a006"
down_revision: str = "20260826a005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "reviews",
        sa.Column("issue_flags", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        schema="app",
    )
    op.create_unique_constraint(
        "uq_reviews_session_id", "reviews", ["session_id"], schema="app"
    )
    op.create_unique_constraint(
        "uq_payments_booking_id", "payments", ["booking_id"], schema="app"
    )
    op.create_unique_constraint(
        "uq_payments_provider_order_id",
        "payments",
        ["provider_order_id"],
        schema="app",
    )
    op.create_unique_constraint(
        "uq_payments_provider_payment_id",
        "payments",
        ["provider_payment_id"],
        schema="app",
    )
    op.create_unique_constraint(
        "uq_charging_sessions_booking_id",
        "charging_sessions",
        ["booking_id"],
        schema="app",
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_charging_sessions_booking_id",
        "charging_sessions",
        schema="app",
        type_="unique",
    )
    op.drop_constraint(
        "uq_payments_provider_payment_id",
        "payments",
        schema="app",
        type_="unique",
    )
    op.drop_constraint(
        "uq_payments_provider_order_id",
        "payments",
        schema="app",
        type_="unique",
    )
    op.drop_constraint(
        "uq_payments_booking_id", "payments", schema="app", type_="unique"
    )
    op.drop_constraint(
        "uq_reviews_session_id", "reviews", schema="app", type_="unique"
    )
    op.drop_column("reviews", "issue_flags", schema="app")
