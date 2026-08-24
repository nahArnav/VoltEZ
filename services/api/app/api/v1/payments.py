from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, timezone

from app.db.session import get_db
from app.models.user import User
from app.api.v1.deps import get_current_user
from app.schemas.payment import PaymentCreate, PaymentResponse
from app.repositories.payment import payment_repo

router = APIRouter(prefix="/payments", tags=["Payments"])

@router.post("/create-order", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
async def create_order(
    payment_in: PaymentCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a Razorpay order and save the pending payment to the database.
    """
    # Razorpay order logic goes here when the integration is ready.
    payment_data = payment_in.model_dump()
    payment_data["provider_order_id"] = "rzp_test_order_placeholder"
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
    """
    payload = await request.json()
    
    # Signature verification logic goes here.
    event_type = payload.get("event")
    
    if event_type == "payment.captured":
        payment_entity = payload.get("payload", {}).get("payment", {}).get("entity", {})
        provider_order_id = payment_entity.get("order_id")
        provider_payment_id = payment_entity.get("id")
        
        payment = await payment_repo.get_by_provider_order(db, provider_order_id=provider_order_id)
        if payment:
            await payment_repo.update(
                db, 
                db_obj=payment, 
                obj_in={
                    "status": "completed", 
                    "provider_payment_id": provider_payment_id, 
                    "verified_at": datetime.now(timezone.utc)
                }
            )
            # The booking status would also transition to CONFIRMED here.
            
    return {"status": "ok"}
