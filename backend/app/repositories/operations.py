from uuid import UUID

from pydantic import BaseModel
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.base import BaseRepository
from app.schemas.charger_status_event import ChargerStatusEventCreate
from app.schemas.demand_history import DemandHistoryCreate
from app.schemas.ml_prediction import MLPredictionCreate
from app.schemas.notification import NotificationCreate, NotificationUpdate
from database.models.charger_status_event import ChargerStatusEvent
from database.models.demand_history import DemandHistory
from database.models.ml_prediction import MLPrediction
from database.models.notification import Notification


# Fallback empty schemas for updates where we don't do partial updates
class EmptyUpdate(BaseModel):
    pass


class RepositoryNotification(BaseRepository[Notification, NotificationCreate, NotificationUpdate]):
    async def get_pending(self, db: AsyncSession) -> list[Notification]:
        result = await db.execute(select(Notification).where(Notification.status == "pending"))
        return list(result.scalars().all())


class RepositoryChargerStatusEvent(
    BaseRepository[ChargerStatusEvent, ChargerStatusEventCreate, EmptyUpdate]
):
    async def get_latest_for_charger(
        self, db: AsyncSession, charger_id: UUID
    ) -> ChargerStatusEvent | None:
        result = await db.execute(
            select(ChargerStatusEvent)
            .where(ChargerStatusEvent.charger_id == charger_id)
            .order_by(desc(ChargerStatusEvent.created_at))
            .limit(1)
        )
        return result.scalar_one_or_none()


class RepositoryDemandHistory(BaseRepository[DemandHistory, DemandHistoryCreate, EmptyUpdate]):
    pass


class RepositoryMLPrediction(BaseRepository[MLPrediction, MLPredictionCreate, EmptyUpdate]):
    pass


notification_repo = RepositoryNotification(Notification)
status_event_repo = RepositoryChargerStatusEvent(ChargerStatusEvent)
demand_repo = RepositoryDemandHistory(DemandHistory)
ml_prediction_repo = RepositoryMLPrediction(MLPrediction)
