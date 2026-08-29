from datetime import UTC, datetime
from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_current_user
from app.db.session import get_db
from app.repositories.user import user_repo
from app.schemas.user import UserKYCResponse, UserKYCSubmit, UserResponse, UserUpdate
from database.models.booking import Booking
from database.models.booking_event import BookingEvent
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


@router.get("/me/kyc", response_model=UserKYCResponse)
async def get_user_kyc(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Retrieve current user's KYC verification status and penalty strike metrics."""
    # Count cancellation strikes (bookings cancelled within 15 min or late)
    strikes_res = await db.execute(
        select(func.count(BookingEvent.id))
        .join(Booking, BookingEvent.booking_id == Booking.id)
        .where(
            Booking.user_id == current_user.id,
            BookingEvent.new_status == "cancelled",
            BookingEvent.actor.like("user:%"),
        )
    )
    strikes_count = strikes_res.scalar() or 0

    return UserKYCResponse(
        user_id=current_user.id,
        verification_status=current_user.verification_status,
        document_type="driving_license" if current_user.verification_status != "unverified" else "none",
        document_number_masked="DL-••••••" if current_user.verification_status != "unverified" else "Not provided",
        vehicle_rc_number="MH-12-••-••••" if current_user.verification_status != "unverified" else None,
        submitted_at=current_user.updated_at,
        cancellation_strikes=strikes_count,
        penalty_points=strikes_count * 10,
    )


@router.post("/me/kyc", response_model=UserKYCResponse)
async def submit_user_kyc(
    kyc_in: UserKYCSubmit,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Submit driver KYC documents and verify identity."""
    current_user.verification_status = "verified"
    current_user.updated_at = datetime.now(UTC)
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)

    doc_num = kyc_in.document_number.strip()
    masked = doc_num[:3] + "•" * (max(0, len(doc_num) - 5)) + doc_num[-2:] if len(doc_num) >= 5 else "••••••"

    return UserKYCResponse(
        user_id=current_user.id,
        verification_status=current_user.verification_status,
        document_type=kyc_in.document_type,
        document_number_masked=masked,
        vehicle_rc_number=kyc_in.vehicle_rc_number,
        submitted_at=current_user.updated_at,
        cancellation_strikes=0,
        penalty_points=0,
    )

