from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.base import BaseRepository
from app.schemas.charging_session import ChargingSessionCreate, ChargingSessionUpdate
from app.schemas.payment import PaymentCreate, PaymentUpdate
from app.schemas.review import ReviewBase, ReviewCreate
from database.models.charging_session import ChargingSession
from database.models.payment import Payment
from database.models.review import Review


class RepositoryChargingSession(
    BaseRepository[ChargingSession, ChargingSessionCreate, ChargingSessionUpdate]
):
    async def get_by_booking(self, db: AsyncSession, booking_id: UUID) -> ChargingSession | None:
        result = await db.execute(
            select(ChargingSession).where(ChargingSession.booking_id == booking_id)
        )
        return result.scalar_one_or_none()

    async def get_by_user(self, db: AsyncSession, user_id: UUID) -> list[ChargingSession]:
        result = await db.execute(
            select(ChargingSession)
            .where(ChargingSession.user_id == user_id)
            .order_by(ChargingSession.reserved_at.desc())
        )
        return list(result.scalars().all())


class RepositoryPayment(BaseRepository[Payment, PaymentCreate, PaymentUpdate]):
    async def get_by_provider_id(
        self, db: AsyncSession, provider_payment_id: str
    ) -> Payment | None:
        result = await db.execute(
            select(Payment).where(Payment.provider_payment_id == provider_payment_id)
        )
        return result.scalar_one_or_none()


class RepositoryReview(BaseRepository[Review, ReviewCreate, ReviewBase]):
    async def get_by_session(self, db: AsyncSession, session_id: UUID) -> Review | None:
        result = await db.execute(select(Review).where(Review.session_id == session_id))
        return result.scalar_one_or_none()


session_repo = RepositoryChargingSession(ChargingSession)
payment_repo = RepositoryPayment(Payment)
review_repo = RepositoryReview(Review)
