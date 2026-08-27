import logging
from uuid import UUID

from fastapi.encoders import jsonable_encoder
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.operations import notification_repo
from app.schemas.notification import NotificationCreate
from app.websockets.manager import manager

logger = logging.getLogger(__name__)


class FCMService:
    @staticmethod
    async def send_push_notification(
        db: AsyncSession, user_id: UUID, title: str, body: str, payload: dict | None = None
    ):
        """
        Sends a push notification via Firebase Cloud Messaging (FCM) and saves it to the DB.
        Currently mocked for development/hackathon purposes.
        """
        # Notification payloads are stored in PostgreSQL JSONB.  Domain events
        # commonly contain UUID/datetime values, so normalise them at this
        # boundary instead of allowing a late JSON serialization failure.
        payload = jsonable_encoder(payload or {})

        # 1. Save to Database
        notification_in = NotificationCreate(
            user_id=user_id,
            type=payload.get("type", payload.get("event", "system")),
            title=title,
            message=body,
            data=payload,
            status="unread",
        )
        await notification_repo.create(db, obj_in=notification_in)
        await db.commit()

        # 2. Mock FCM API Call
        logger.info(
            f"[MOCK FCM] Sending push to user {user_id}: {title} - {body} | payload={payload}"
        )

        # 3. Fallback: Push to WebSocket if the user is currently connected to the app
        ws_payload = {"event": "notification", "title": title, "body": body, "data": payload}
        await manager.send_personal_message(ws_payload, user_id)


fcm_service = FCMService()
