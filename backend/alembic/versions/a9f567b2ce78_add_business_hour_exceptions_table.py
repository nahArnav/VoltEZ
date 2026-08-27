"""add business hour exceptions table

Revision ID: a9f567b2ce78
Revises: 96e960d81f19
Create Date: 2026-08-23 01:24:43.669886

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a9f567b2ce78"
down_revision: str | Sequence[str] | None = "96e960d81f19"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "business_hour_exceptions",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("business_id", sa.UUID(), nullable=False),
        sa.Column("start_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("exception_type", sa.String(length=30), nullable=False),
        sa.Column("reason", sa.String(length=500), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["business_id"],
            ["app.businesses.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        schema="app",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table(
        "business_hour_exceptions",
        schema="app",
        if_exists=True,
    )
