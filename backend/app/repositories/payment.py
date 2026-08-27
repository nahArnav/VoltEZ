from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.base import BaseRepository
from app.schemas.payment import PaymentCreate, PaymentUpdate
from database.models.payment import Payment


class RepositoryPayment(BaseRepository[Payment, PaymentCreate, PaymentUpdate]):
    async def get_by_booking(self, db: AsyncSession, booking_id: UUID) -> Payment | None:
        """Fetch payment by booking ID."""
        result = await db.execute(select(Payment).where(Payment.booking_id == booking_id))
        return result.scalars().first()

    async def get_by_provider_order(
        self, db: AsyncSession, provider_order_id: str
    ) -> Payment | None:
        """Fetch payment by gateway order ID (e.g. Razorpay order_id)."""
        result = await db.execute(
            select(Payment).where(Payment.provider_order_id == provider_order_id)
        )
        return result.scalars().first()


payment_repo = RepositoryPayment(Payment)
