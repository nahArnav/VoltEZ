from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_current_user
from app.db.session import get_db
from app.repositories.user import user_repo
from app.schemas.notification import NotificationResponse, NotificationUpdate
from app.schemas.user import UserKYCResponse, UserKYCSubmit, UserResponse, UserUpdate
from database.models.notification import Notification
from database.models.user import User

router = APIRouter(prefix="/users", tags=["Users"])



@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """Get current user profile."""
    return current_user


@router.patch("/me", response_model=UserResponse)
async def update_me(
    user_in: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update current user profile."""
    updated_user = await user_repo.update(db, db_obj=current_user, obj_in=user_in)
    await db.commit()
    await db.refresh(updated_user)
    return updated_user


@router.get("/me/notifications", response_model=list[NotificationResponse])
async def list_my_notifications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .order_by(desc(Notification.created_at))
        .limit(100)
    )
    return list(result.scalars().all())


@router.patch("/me/notifications/{notification_id}", response_model=NotificationResponse)
async def update_my_notification(
    notification_id: UUID,
    notification_in: NotificationUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == current_user.id,
        )
    )
    notification = result.scalar_one_or_none()
    if notification is None:
        raise HTTPException(status_code=404, detail="Notification not found")
    if notification_in.status is not None:
        notification.status = notification_in.status
    if notification_in.read_at is not None:
        notification.read_at = notification_in.read_at
    elif notification_in.status == "read":
        notification.read_at = datetime.now(UTC)
    db.add(notification)
    await db.commit()
    await db.refresh(notification)
    return notification


@router.get("/me/kyc", response_model=UserKYCResponse)
async def get_user_kyc(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Retrieve current user's KYC verification status and penalty strike metrics."""
    return UserKYCResponse(
        user_id=current_user.id,
        verification_status=current_user.verification_status,
        document_type=current_user.kyc_document_type or "none",
        document_number_masked=current_user.kyc_document_masked or "Not provided",
        vehicle_rc_number=current_user.kyc_vehicle_rc_masked,
        submitted_at=current_user.kyc_submitted_at or current_user.updated_at,
        cancellation_strikes=current_user.cancellation_strikes,
        penalty_points=current_user.penalty_points,
        suspended_until=current_user.suspended_until,
    )


@router.post("/me/kyc", response_model=UserKYCResponse)
async def submit_user_kyc(
    kyc_in: UserKYCSubmit,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Submit driver KYC documents and verify identity."""
    doc_num = kyc_in.document_number.strip()
    rc_num = kyc_in.vehicle_rc_number.strip() if kyc_in.vehicle_rc_number else None
    if len(doc_num) < 5:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="KYC document number is too short")

    now = datetime.now(UTC)
    # Submission is not verification. A provider or admin review must approve it.
    current_user.verification_status = "pending"
    current_user.kyc_document_type = kyc_in.document_type
    current_user.kyc_document_masked = doc_num[:3] + "•" * (len(doc_num) - 5) + doc_num[-2:]
    current_user.kyc_vehicle_rc_masked = (
        rc_num[:3] + "•" * (len(rc_num) - 5) + rc_num[-2:]
        if rc_num and len(rc_num) >= 5
        else None
    )
    current_user.kyc_submitted_at = now
    current_user.updated_at = now
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)

    return UserKYCResponse(
        user_id=current_user.id,
        verification_status=current_user.verification_status,
        document_type=kyc_in.document_type,
        document_number_masked=current_user.kyc_document_masked or "Not provided",
        vehicle_rc_number=current_user.kyc_vehicle_rc_masked,
        submitted_at=current_user.kyc_submitted_at,
        cancellation_strikes=current_user.cancellation_strikes,
        penalty_points=current_user.penalty_points,
        suspended_until=current_user.suspended_until,
    )
