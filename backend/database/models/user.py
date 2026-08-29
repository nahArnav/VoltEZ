import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from database.base_class import Base


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint(
            "email IS NOT NULL OR phone IS NOT NULL",
            name="ck_users_email_or_phone",
        ),
        CheckConstraint(
            "btrim(name) <> ''",
            name="ck_users_name_not_blank",
        ),
        CheckConstraint(
            "email IS NULL OR btrim(email) <> ''",
            name="ck_users_email_not_blank",
        ),
        CheckConstraint(
            "phone IS NULL OR btrim(phone) <> ''",
            name="ck_users_phone_not_blank",
        ),
        CheckConstraint(
            "role IN ('driver', 'owner', 'admin')",
            name="ck_users_role",
        ),
        CheckConstraint(
            "verification_status IN ('unverified', 'pending', 'verified', 'rejected')",
            name="ck_users_verification_status",
        ),
        CheckConstraint("cancellation_strikes >= 0", name="ck_users_cancellation_strikes"),
        CheckConstraint("penalty_points >= 0", name="ck_users_penalty_points"),
        {"schema": "app"},
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    name: Mapped[str] = mapped_column(String(150), nullable=False)

    email: Mapped[str | None] = mapped_column(
        String(255),
        unique=True,
        nullable=True,
    )

    phone: Mapped[str | None] = mapped_column(
        String(20),
        unique=True,
        nullable=True,
    )

    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    role: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="driver",
    )

    verification_status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="unverified",
    )

    # Only masked KYC values are retained. Raw identity numbers must never be
    # returned by the API or logged by the application.
    kyc_document_type: Mapped[str | None] = mapped_column(String(30), nullable=True)
    kyc_document_masked: Mapped[str | None] = mapped_column(String(80), nullable=True)
    kyc_vehicle_rc_masked: Mapped[str | None] = mapped_column(String(80), nullable=True)
    kyc_submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    cancellation_strikes: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    penalty_points: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    suspended_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    timezone: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        default="Asia/Kolkata",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
