from datetime import UTC, datetime
from decimal import Decimal

import razorpay
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_current_user
from app.core.config import settings
from app.db.session import get_db
from app.repositories.booking import booking_repo
from app.repositories.payment import payment_repo
from app.schemas.enums import BookingStatus
from app.schemas.payment import (
    PaymentOrderCreate,
    PaymentResponse,
    PaymentVerifyRequest,
)
from database.models.booking_event import BookingEvent
from database.models.user import User

router = APIRouter(prefix="/payments", tags=["Payments"])

# Initialize Razorpay Client
razorpay_client = razorpay.Client(auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET))


async def _require_owned_booking(db: AsyncSession, booking_id, current_user: User):
    booking = await booking_repo.get(db, id=booking_id)
    if booking is None or booking.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Booking not found")
    return booking


def _require_payable_booking(booking):
    if booking.status not in {BookingStatus.HELD.value, BookingStatus.PENDING.value}:
        raise HTTPException(
            status_code=409,
            detail=f"Booking cannot be paid while it is {booking.status}.",
        )
    if booking.hold_expires_at and booking.hold_expires_at <= datetime.now(UTC):
        raise HTTPException(status_code=409, detail="Booking hold has expired")
    return booking


async def _confirm_payment(db: AsyncSession, payment, provider_payment_id: str):
    """Idempotently confirm a verified payment and its booking in one transaction."""
    if payment.status == "completed":
        return await booking_repo.get(db, id=payment.booking_id)

    booking = await booking_repo.get(db, id=payment.booking_id)
    if booking is None:
        raise HTTPException(status_code=404, detail="Booking not found")

    payment.status = "completed"
    payment.provider_payment_id = provider_payment_id
    payment.verified_at = datetime.now(UTC)
    if booking.status in {BookingStatus.HELD.value, BookingStatus.PENDING.value}:
        old_status = booking.status
        booking.status = BookingStatus.CONFIRMED.value
        db.add(
            BookingEvent(
                booking_id=booking.id,
                old_status=old_status,
                new_status=BookingStatus.CONFIRMED.value,
                actor="system:payment-verification",
                metadata_={"provider_payment_id": provider_payment_id},
            )
        )
    db.add_all([payment, booking])
    await db.commit()
    await db.refresh(payment)
    return booking


@router.post("/create-order", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
async def create_order(
    payment_in: PaymentOrderCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Create a Razorpay order and save the pending payment to the database.
    """
    booking = await _require_owned_booking(db, payment_in.booking_id, current_user)
    existing = await payment_repo.get_by_booking(db, booking_id=booking.id)
    if existing and existing.status in {"pending", "completed"}:
        return existing
    _require_payable_booking(booking)

    amount = Decimal(str(booking.estimated_amount or settings.BOOKING_HOLD_FEE_INR))
    amount_in_paise = int(amount * 100)

    # Cash is an explicit pay-at-charger method. We confirm the reservation,
    # but leave the payment pending so settlement is only recorded after the
    # charging session completes (or an owner verifies cash collection).
    if payment_in.method == "cash":
        old_status = booking.status
        payment = await payment_repo.create(
            db,
            obj_in={
                "booking_id": booking.id,
                "amount": amount,
                "currency": "INR",
                "method": "cash",
                "status": "pending",
            },
        )
        booking.status = BookingStatus.CONFIRMED.value
        db.add(
            BookingEvent(
                booking_id=booking.id,
                old_status=old_status,
                new_status=BookingStatus.CONFIRMED.value,
                actor="user:cash-pay-at-charger",
                metadata_={"payment_method": "cash"},
            )
        )
        db.add(booking)
        await db.commit()
        await db.refresh(payment)
        return payment

    if not settings.razorpay_is_configured:
        raise HTTPException(status_code=503, detail="Razorpay is not configured")

    # Try/except block in case Razorpay API is down
    try:
        rzp_order = razorpay_client.order.create(
            {  # type: ignore
                "amount": amount_in_paise,
                "currency": "INR",
                "receipt": f"booking_{payment_in.booking_id}",
            }
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail="Payment provider unavailable"
        ) from e

    # 2. Save the pending payment to our database
    payment_data = {
        "booking_id": booking.id,
        "amount": amount,
        "currency": "INR",
        "method": payment_in.method,
        "provider_order_id": rzp_order.get("id"),
        "status": "pending",
    }

    payment = await payment_repo.create(db, obj_in=payment_data)
    await db.commit()
    await db.refresh(payment)
    return payment


@router.post("/verify", response_model=PaymentResponse)
async def verify_payment(
    payment_in: PaymentVerifyRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Verify the checkout signature and atomically confirm the payment/booking."""
    if not settings.razorpay_is_configured:
        raise HTTPException(status_code=503, detail="Razorpay is not configured")

    booking = await _require_owned_booking(db, payment_in.booking_id, current_user)
    payment = await payment_repo.get_by_provider_order(
        db, provider_order_id=payment_in.provider_order_id
    )
    if payment is None or payment.booking_id != payment_in.booking_id:
        raise HTTPException(status_code=404, detail="Payment order not found")
    if payment.status == "completed":
        return payment
    _require_payable_booking(booking)

    try:
        razorpay_client.utility.verify_payment_signature(  # type: ignore
            {
                "razorpay_order_id": payment_in.provider_order_id,
                "razorpay_payment_id": payment_in.provider_payment_id,
                "razorpay_signature": payment_in.provider_signature,
            }
        )
    except razorpay.errors.SignatureVerificationError as exc:  # type: ignore
        raise HTTPException(status_code=400, detail="Invalid payment signature") from exc

    await _confirm_payment(db, payment, payment_in.provider_payment_id)
    return payment


@router.post("/webhook")
async def razorpay_webhook(request: Request, db: AsyncSession = Depends(get_db)):
    """
    Handle Razorpay webhook for payment success or failure.
    Cryptographically verifies the HMAC-SHA256 signature to prevent fraud.
    """
    body = await request.body()
    signature = request.headers.get("x-razorpay-signature")

    if not signature:
        raise HTTPException(status_code=400, detail="Missing signature")

    try:
        razorpay_client.utility.verify_webhook_signature(  # type: ignore
            body.decode("utf-8"), signature, settings.RAZORPAY_WEBHOOK_SECRET
        )
    except razorpay.errors.SignatureVerificationError:  # type: ignore
        raise HTTPException(status_code=400, detail="Invalid signature")

    # If signature is valid, process the event
    payload = await request.json()
    event_type = payload.get("event")

    if event_type == "payment.captured":
        payment_entity = payload.get("payload", {}).get("payment", {}).get("entity", {})
        provider_order_id = payment_entity.get("order_id")
        provider_payment_id = payment_entity.get("id")

        # 1. Update the Payment record to completed
        payment = await payment_repo.get_by_provider_order(db, provider_order_id=provider_order_id)
        if payment:
            await _confirm_payment(db, payment, provider_payment_id)

    return {"status": "ok"}
