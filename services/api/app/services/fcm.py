from sqlalchemy.ext.asyncio import AsyncSession
import logging

from app.schemas.notification import NotificationCreate
from app.repositories.operations import notification_repo
from app.websockets.manager import manager

logger = logging.getLogger(__name__)

class FCMService:
    @staticmethod
    async def send_push_notification(
        db: AsyncSession, 
        user_id: int, 
        title: str, 
        body: str, 
        payload: dict | None = None
    ):
        """
        Sends a push notification via Firebase Cloud Messaging (FCM) and saves it to the DB.
        Currently mocked for development/hackathon purposes.
        """
        payload = payload or {}
        
        # Merge title and body into payload since Notification schema expects it
        db_payload = {**payload, "title": title, "body": body}
        
        # 1. Save to Database
        notification_in = NotificationCreate(
            user_id=user_id,
            type=payload.get("type", "system"),
            payload=db_payload,
            status="sent" # Since it's a mock, we assume it sent instantly
        )
        await notification_repo.create(db, obj_in=notification_in)
        
        # 2. Mock FCM API Call
        logger.info(f"[MOCK FCM] Sending push to user {user_id}: {title} - {body} | payload={payload}")
        
        # 3. Fallback: Push to WebSocket if the user is currently connected to the app
        ws_payload = {
            "event": "notification",
            "title": title,
            "body": body,
            "data": payload
        }
        await manager.send_personal_message(ws_payload, user_id)


fcm_service = FCMService()
