import asyncio
from datetime import UTC, datetime
from decimal import Decimal

import razorpay

try:
    import stripe
except ImportError:  # pragma: no cover - dependency is installed in deployment
    stripe = None
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
    StripeVerifyRequest,
)
from app.services.cash import issue_cash_otp
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
    if existing and existing.status == "completed":
        return existing

    # A driver may reopen checkout after the app was backgrounded. For an
    # already-confirmed cash booking, rotate the one-time code and return it
    # again rather than rejecting the retry as non-payable.
    if (
        payment_in.method == "cash"
        and existing is not None
        and existing.status == "pending"
        and existing.method == "cash"
        and booking.status == BookingStatus.CONFIRMED.value
    ):
        cash_otp, cash_otp_expires_at = issue_cash_otp(booking)
        db.add(booking)
        await db.commit()
        await db.refresh(existing)
        response = PaymentResponse.model_validate(existing)
        response.provider = "cash"
        response.cash_otp = cash_otp
        response.cash_otp_expires_at = cash_otp_expires_at
        return response

    _require_payable_booking(booking)

    # A booking has one auditable payment row. If the driver changes method
    # before completing checkout, reuse that row instead of violating the
    # one-payment-per-booking constraint. Gateway orders are disposable, so a
    # new card/UPI order can safely replace an abandoned pending order.
    if existing and existing.status == "pending" and existing.method == payment_in.method:
        if payment_in.method == "cash" or existing.provider_order_id:
            return existing

    amount = Decimal(str(booking.estimated_amount or settings.BOOKING_HOLD_FEE_INR))
    amount_in_paise = int(amount * 100)

    # Cash is an explicit pay-at-charger method. We confirm the reservation,
    # but leave the payment pending so settlement is only recorded after the
    # charging session completes (or an owner verifies cash collection).
    if payment_in.method == "cash":
        old_status = booking.status
        cash_otp, cash_otp_expires_at = issue_cash_otp(booking)
        if existing is None:
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
        else:
            payment = existing
            payment.amount = amount
            payment.currency = "INR"
            payment.method = "cash"
            payment.status = "pending"
            payment.provider_order_id = None
            payment.provider_payment_id = None
            payment.verified_at = None
        booking.status = BookingStatus.CONFIRMED.value
        if old_status != BookingStatus.CONFIRMED.value:
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
        response = PaymentResponse.model_validate(payment)
        response.provider = "cash"
        response.cash_otp = cash_otp
        response.cash_otp_expires_at = cash_otp_expires_at
        return response

    if settings.active_payment_provider == "stripe":
        if stripe is None or not settings.stripe_is_configured:
            raise HTTPException(status_code=503, detail="Stripe is not configured")
        stripe.api_key = settings.STRIPE_SECRET_KEY
        try:
            session = await asyncio.to_thread(
                stripe.checkout.Session.create,
                mode="payment",
                line_items=[
                    {
                        "price_data": {
                            "currency": "inr",
                            "product_data": {"name": "VoltEZ charging reservation"},
                            "unit_amount": amount_in_paise,
                        },
                        "quantity": 1,
                    }
                ],
                metadata={"booking_id": str(booking.id)},
                success_url=settings.STRIPE_SUCCESS_URL,
                cancel_url=settings.STRIPE_CANCEL_URL,
            )
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Stripe checkout is temporarily unavailable",
            ) from exc
        payment_data = {
            "booking_id": booking.id,
            "amount": amount,
            "currency": "INR",
            "method": payment_in.method,
            "provider_order_id": session.id,
            "status": "pending",
        }
        if existing is None:
            payment = await payment_repo.create(db, obj_in=payment_data)
        else:
            payment = existing
            for key, value in payment_data.items():
                setattr(payment, key, value)
            payment.provider_payment_id = None
            payment.verified_at = None
            db.add(payment)
        await db.commit()
        await db.refresh(payment)
        response = PaymentResponse.model_validate(payment)
        response.provider = "stripe"
        response.checkout_url = getattr(session, "url", None)
        return response

    if not settings.razorpay_is_configured:
        raise HTTPException(status_code=503, detail="No payment provider is configured")

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

    if existing is None:
        payment = await payment_repo.create(db, obj_in=payment_data)
    else:
        payment = existing
        payment.amount = amount
        payment.currency = "INR"
        payment.method = payment_in.method
        payment.provider_order_id = rzp_order.get("id")
        payment.provider_payment_id = None
        payment.status = "pending"
        payment.verified_at = None
        db.add(payment)
    await db.commit()
    await db.refresh(payment)
    response = PaymentResponse.model_validate(payment)
    response.provider = "razorpay"
    return response


@router.post("/stripe/verify", response_model=PaymentResponse)
async def verify_stripe_payment(
    payment_in: StripeVerifyRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Verify a hosted Stripe Checkout session before confirming a booking."""
    if stripe is None or not settings.stripe_is_configured:
        raise HTTPException(status_code=503, detail="Stripe is not configured")
    booking = await _require_owned_booking(db, payment_in.booking_id, current_user)
    payment = await payment_repo.get_by_provider_order(
        db, provider_order_id=payment_in.checkout_session_id
    )
    if payment is None or payment.booking_id != booking.id:
        raise HTTPException(status_code=404, detail="Stripe checkout session not found")
    if payment.status == "completed":
        response = PaymentResponse.model_validate(payment)
        response.provider = "stripe"
        return response
    _require_payable_booking(booking)
    stripe.api_key = settings.STRIPE_SECRET_KEY
    try:
        session = await asyncio.to_thread(
            stripe.checkout.Session.retrieve,
            payment_in.checkout_session_id,
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Stripe verification unavailable") from exc
    if (
        getattr(session, "payment_status", None) != "paid"
        or (getattr(session, "metadata", {}) or {}).get("booking_id") != str(booking.id)
    ):
        raise HTTPException(status_code=400, detail="Stripe payment has not been completed")
    await _confirm_payment(
        db,
        payment,
        str(getattr(session, "payment_intent", None) or payment_in.checkout_session_id),
    )
    response = PaymentResponse.model_validate(payment)
    response.provider = "stripe"
    return response


@router.post("/stripe/webhook")
async def stripe_webhook(request: Request, db: AsyncSession = Depends(get_db)):
    """Consume Stripe's signed checkout completion event for async truth."""
    if stripe is None or not settings.stripe_is_configured:
        raise HTTPException(status_code=503, detail="Stripe is not configured")
    signature = request.headers.get("stripe-signature")
    if not signature or settings.STRIPE_WEBHOOK_SECRET == "whsec_test_placeholder":
        raise HTTPException(status_code=400, detail="Missing Stripe webhook signature")
    body = await request.body()
    try:
        event = stripe.Webhook.construct_event(
            body,
            signature,
            settings.STRIPE_WEBHOOK_SECRET,
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid Stripe webhook signature") from exc
    if event.get("type") == "checkout.session.completed":
        session = event.get("data", {}).get("object", {})
        session_id = session.get("id")
        metadata = session.get("metadata") or {}
        booking_id = metadata.get("booking_id")
        if session.get("payment_status") == "paid" and session_id and booking_id:
            payment = await payment_repo.get_by_provider_order(db, provider_order_id=session_id)
            if payment and str(payment.booking_id) == str(booking_id):
                await _confirm_payment(
                    db,
                    payment,
                    str(session.get("payment_intent") or session_id),
                )
    return {"status": "ok"}


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
