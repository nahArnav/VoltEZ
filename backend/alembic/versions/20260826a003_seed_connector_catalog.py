"""seed the connector-type reference catalog

Revision ID: 20260826a003
Revises: 20260826a002
Create Date: 2026-08-26 14:55:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260826a003"
down_revision: str = "20260826a002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


connector_types = sa.table(
    "connector_types",
    sa.column("id", sa.Integer()),
    sa.column("code", sa.String()),
    sa.column("display_name", sa.String()),
    sa.column("current_type", sa.String()),
    schema="app",
)


def upgrade() -> None:
    op.bulk_insert(
        connector_types,
        [
            {"id": 1, "code": "ccs2", "display_name": "CCS2", "current_type": "DC"},
            {"id": 2, "code": "type_2", "display_name": "Type 2", "current_type": "AC"},
            {"id": 3, "code": "chademo", "display_name": "CHAdeMO", "current_type": "DC"},
            {
                "id": 4,
                "code": "bharat_ac_001",
                "display_name": "Bharat AC-001",
                "current_type": "AC",
            },
            {
                "id": 5,
                "code": "bharat_dc_001",
                "display_name": "Bharat DC-001",
                "current_type": "DC",
            },
        ],
    )
    op.execute(
        "SELECT setval(pg_get_serial_sequence('app.connector_types', 'id'), "
        "(SELECT max(id) FROM app.connector_types))"
    )


def downgrade() -> None:
    op.execute("DELETE FROM app.connector_types WHERE id BETWEEN 1 AND 5")
