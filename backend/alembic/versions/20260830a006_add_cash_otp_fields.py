"""add hashed OTP fields for cash reservations"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260830a006"
down_revision: str | Sequence[str] | None = "20260830a005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("bookings", sa.Column("cash_otp_hash", sa.String(length=128), nullable=True), schema="app")
    op.add_column(
        "bookings",
        sa.Column("cash_otp_expires_at", sa.DateTime(timezone=True), nullable=True),
        schema="app",
    )
    op.add_column(
        "bookings",
        sa.Column("cash_otp_attempts", sa.Integer(), nullable=False, server_default="0"),
        schema="app",
    )
    op.add_column(
        "bookings",
        sa.Column("cash_otp_verified_at", sa.DateTime(timezone=True), nullable=True),
        schema="app",
    )
    op.create_check_constraint(
        "ck_bookings_cash_otp_attempts_nonnegative",
        "bookings",
        "cash_otp_attempts >= 0",
        schema="app",
    )
    op.alter_column("bookings", "cash_otp_attempts", server_default=None, schema="app")


def downgrade() -> None:
    op.drop_constraint(
        "ck_bookings_cash_otp_attempts_nonnegative",
        "bookings",
        schema="app",
        type_="check",
    )
    op.drop_column("bookings", "cash_otp_verified_at", schema="app")
    op.drop_column("bookings", "cash_otp_attempts", schema="app")
    op.drop_column("bookings", "cash_otp_expires_at", schema="app")
    op.drop_column("bookings", "cash_otp_hash", schema="app")
