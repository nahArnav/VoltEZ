from app.schemas.enums import ChargerStatus
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional, cast
from datetime import datetime, timezone

from database.models.charger_status_event import ChargerStatusEvent
from app.repositories.charger import charger_repo


class TrustService:
    @staticmethod
    async def record_event(
        db: AsyncSession,
        charger_id: UUID,
        status: str,
        source: str,
        confidence: float,
        charger_port_id: Optional[UUID] = None
    ):
        """
        Record a status event and adjust the charger's reliability score.
        """
        # 1. Record the audit event
        event = ChargerStatusEvent(
            charger_id=charger_id,
            port_id=charger_port_id,
            status=status,
            source=source,
            confidence=confidence,
            error_code=None,
            details={
                "charger_port_id": str(charger_port_id) if charger_port_id else None
            },
            observed_at=datetime.now(timezone.utc),
        )
        db.add(event)

        # 2. Adjust the reliability score of the charger
        charger = await charger_repo.get(db, id=charger_id)
        if charger:
            current_score = cast(float, getattr(charger, "reliability_score", 100.0))
            if current_score is None:
                current_score = 100.0
            
            # Simple heuristic for No-IoT trust model (Playbook Phase 3)
            if source == "DRIVER_CHECKIN":
                # Check-in confirms it works
                setattr(charger, "reliability_score", min(100.0, current_score + 5.0))
            elif source == "DRIVER_CHECKOUT":
                # Complete session is strong proof
                setattr(charger, "reliability_score", min(100.0, current_score + 5.0))
            elif source == "DRIVER_REPORT":
                # Issue reported = penalize heavily
                setattr(charger, "reliability_score", max(0.0, current_score - 20.0))

            db.add(charger)

trust_service = TrustService()
