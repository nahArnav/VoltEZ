"""seed the Pune reference zone required by business onboarding

Revision ID: 20260826a004
Revises: 20260826a003
Create Date: 2026-08-26 15:05:00.000000
"""

from collections.abc import Sequence

from alembic import op


revision: str = "20260826a004"
down_revision: str = "20260826a003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

PUNE_ZONE_ID = "11111111-1111-4111-8111-111111111111"


def upgrade() -> None:
    op.execute(
        """
        INSERT INTO app.zones (
            id, city, name, h3_index, centroid, timezone, active, zone_type
        ) VALUES (
            '11111111-1111-4111-8111-111111111111',
            'Pune',
            'Pune Central',
            'voltez-pune-central',
            ST_SetSRID(ST_Point(73.8567, 18.5204), 4326),
            'Asia/Kolkata',
            true,
            'commercial'
        )
        ON CONFLICT (id) DO NOTHING
        """
    )


def downgrade() -> None:
    op.execute(
        "DELETE FROM app.zones WHERE id = '11111111-1111-4111-8111-111111111111'"
    )
