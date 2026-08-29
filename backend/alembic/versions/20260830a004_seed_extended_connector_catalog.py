"""add Type 1 and GB/T connector types used by imported Indian EVs"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260830a004"
down_revision: str | Sequence[str] | None = "20260830a003"
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
    # IDs 1–5 are frozen by the original catalog migration.  These explicit
    # IDs keep client payloads stable while adding the two legacy/imported
    # standards exposed by the vehicle onboarding screen.
    op.bulk_insert(
        connector_types,
        [
            {"id": 6, "code": "type_1", "display_name": "Type 1", "current_type": "AC"},
            {"id": 7, "code": "gb_t", "display_name": "GB/T", "current_type": "DC"},
        ],
    )
    op.execute(
        "SELECT setval(pg_get_serial_sequence('app.connector_types', 'id'), "
        "(SELECT max(id) FROM app.connector_types))"
    )


def downgrade() -> None:
    op.execute("DELETE FROM app.connector_types WHERE id IN (6, 7)")
