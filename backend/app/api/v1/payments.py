from app.schemas.enums import BookingStatus
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, timezone
import razorpay

from app.db.session import get_db
from database.models.user import User
from app.api.v1.deps import get_current_user
from app.schemas.payment import PaymentCreate, PaymentResponse
from app.repositories.payment import payment_repo
from app.repositories.booking import booking_repo

from app.core.config import settings

router = APIRouter(prefix="/payments", tags=["Payments"])

# Initialize Razorpay Client
razorpay_client = razorpay.Client(
    auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET)
)

@router.post("/create-order", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
async def create_order(
    payment_in: PaymentCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a Razorpay order and save the pending payment to the database.
    """
    # 1. Create order on Razorpay servers
    amount_in_paise = int(payment_in.amount * 100)
    
    # Try/except block in case Razorpay API is down
    try:
        rzp_order = razorpay_client.order.create({  # type: ignore
            "amount": amount_in_paise,
            "currency": payment_in.currency,
            "receipt": f"booking_{payment_in.booking_id}"
        })
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, 
            detail=f"Razorpay integration error: {str(e)}"
        )

    # 2. Save the pending payment to our database
    payment_data = payment_in.model_dump()
    payment_data["provider_order_id"] = rzp_order.get("id")
    payment_data["status"] = "pending"
    
    payment = await payment_repo.create(db, obj_in=payment_data)
    return payment


@router.post("/webhook")
async def razorpay_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db)
):
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
            body.decode("utf-8"), 
            signature, 
            settings.RAZORPAY_WEBHOOK_SECRET
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
            payment = await payment_repo.update(
                db, 
                db_obj=payment, 
                obj_in={
                    "status": "completed", 
                    "provider_payment_id": provider_payment_id, 
                    "verified_at": datetime.now(timezone.utc)
                }
            )
            
            # 2. Transition the booking status to CONFIRMED so the driver can check-in
            # Cast payment.booking_id to int to satisfy Pylance
            booking_id = payment.booking_id
            booking = await booking_repo.get(db, id=booking_id)
            if booking and (booking.status == BookingStatus.HELD.value):
                setattr(booking, "status", BookingStatus.CONFIRMED.value)
                db.add(booking)
                await db.commit()
            
    return {"status": "ok"}
