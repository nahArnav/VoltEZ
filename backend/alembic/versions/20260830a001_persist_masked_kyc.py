"""persist masked driver and host KYC metadata"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260830a001"
down_revision: str | Sequence[str] | None = "20260829a002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("users", sa.Column("kyc_document_type", sa.String(30), nullable=True), schema="app")
    op.add_column("users", sa.Column("kyc_document_masked", sa.String(80), nullable=True), schema="app")
    op.add_column("users", sa.Column("kyc_vehicle_rc_masked", sa.String(80), nullable=True), schema="app")
    op.add_column("users", sa.Column("kyc_submitted_at", sa.DateTime(timezone=True), nullable=True), schema="app")

    op.add_column("businesses", sa.Column("kyc_gstin_masked", sa.String(40), nullable=True), schema="app")
    op.add_column("businesses", sa.Column("kyc_pan_masked", sa.String(30), nullable=True), schema="app")
    op.add_column("businesses", sa.Column("kyc_electricity_meter_masked", sa.String(80), nullable=True), schema="app")
    op.add_column("businesses", sa.Column("kyc_payout_upi_masked", sa.String(120), nullable=True), schema="app")
    op.add_column("businesses", sa.Column("kyc_submitted_at", sa.DateTime(timezone=True), nullable=True), schema="app")


def downgrade() -> None:
    op.drop_column("businesses", "kyc_submitted_at", schema="app")
    op.drop_column("businesses", "kyc_payout_upi_masked", schema="app")
    op.drop_column("businesses", "kyc_electricity_meter_masked", schema="app")
    op.drop_column("businesses", "kyc_pan_masked", schema="app")
    op.drop_column("businesses", "kyc_gstin_masked", schema="app")
    op.drop_column("users", "kyc_submitted_at", schema="app")
    op.drop_column("users", "kyc_vehicle_rc_masked", schema="app")
    op.drop_column("users", "kyc_document_masked", schema="app")
    op.drop_column("users", "kyc_document_type", schema="app")
