import asyncio
from datetime import UTC, datetime
from typing import Any
import httpx

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger("n8n_service")


class N8nService:
    """Service to dispatch events and webhooks to n8n workflow automations."""

    @staticmethod
    async def dispatch_webhook(payload: dict[str, Any], webhook_url: str | None = None) -> dict[str, Any]:
        """Dispatch a JSON payload to an n8n webhook asynchronously with graceful error handling."""
        target_url = (webhook_url or settings.N8N_WEBHOOK_URL).strip()
        if not target_url:
            logger.info("n8n webhook skipped: N8N_WEBHOOK_URL is not configured.")
            return {"status": "skipped", "reason": "N8N_WEBHOOK_URL not configured"}

        headers = {"Content-Type": "application/json"}
        if settings.N8N_WEBHOOK_SECRET:
            headers["X-Webhook-Secret"] = settings.N8N_WEBHOOK_SECRET

        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.post(target_url, json=payload, headers=headers)
                if response.status_code in (200, 201, 202, 204):
                    logger.info("Successfully delivered webhook to n8n: %s", target_url)
                    return {"status": "delivered", "status_code": response.status_code}
                else:
                    logger.warning(
                        "n8n webhook returned non-success HTTP status %s: %s",
                        response.status_code,
                        response.text[:200],
                    )
                    return {"status": "error", "status_code": response.status_code}
        except Exception as exc:
            logger.warning("Failed to deliver webhook to n8n at %s: %s", target_url, exc)
            return {"status": "failed", "error": str(exc)}

    @classmethod
    async def send_incident_alert(
        cls,
        station_id: str,
        station_name: str,
        status: str = "offline",
        offline_duration_minutes: int = 15,
        available_ports: int = 0,
        total_ports: int = 4,
        notes: str | None = None,
    ) -> dict[str, Any]:
        """
        Send charger outage or degradation event to n8n incident automation workflow.
        Matches the VoltEZ incident payload specification.
        """
        payload = {
            "event_type": "charger_incident",
            "station_id": station_id,
            "station_name": station_name,
            "status": status,
            "offline_duration_minutes": offline_duration_minutes,
            "available_ports": available_ports,
            "total_ports": total_ports,
            "notes": notes,
            "timestamp": datetime.now(UTC).isoformat(),
        }
        return await cls.dispatch_webhook(payload)

    @classmethod
    async def send_booking_notification(
        cls,
        booking_id: str,
        user_id: str,
        charger_id: str | None = None,
        charger_name: str | None = None,
        status: str = "confirmed",
        power_kw: float | None = None,
        quoted_price_per_kwh: float | None = None,
        start_at: str | None = None,
        end_at: str | None = None,
    ) -> dict[str, Any]:
        """Dispatch booking creation/update lifecycle events to n8n."""
        payload = {
            "event_type": "booking_event",
            "booking_id": booking_id,
            "user_id": user_id,
            "charger_id": charger_id,
            "charger_name": charger_name,
            "status": status,
            "power_kw": power_kw,
            "quoted_price_per_kwh": quoted_price_per_kwh,
            "start_at": start_at,
            "end_at": end_at,
            "timestamp": datetime.now(UTC).isoformat(),
        }
        return await cls.dispatch_webhook(payload)

    @classmethod
    def fire_and_forget_booking_notification(
        cls,
        booking_id: str,
        user_id: str,
        charger_id: str | None = None,
        charger_name: str | None = None,
        status: str = "confirmed",
        power_kw: float | None = None,
        quoted_price_per_kwh: float | None = None,
        start_at: str | None = None,
        end_at: str | None = None,
    ) -> None:
        """Schedule background task to send booking notification without blocking response."""
        try:
            loop = asyncio.get_running_loop()
            loop.create_task(
                cls.send_booking_notification(
                    booking_id=booking_id,
                    user_id=user_id,
                    charger_id=charger_id,
                    charger_name=charger_name,
                    status=status,
                    power_kw=power_kw,
                    quoted_price_per_kwh=quoted_price_per_kwh,
                    start_at=start_at,
                    end_at=end_at,
                )
            )
        except RuntimeError:
            pass


n8n_service = N8nService()
