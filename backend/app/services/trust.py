from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional, cast

from app.models.charger_status_event import ChargerStatusEvent
from app.repositories.charger import charger_repo


class TrustService:
    @staticmethod
    async def record_event(
        db: AsyncSession,
        charger_id: int,
        status: str,
        source: str,
        confidence: float,
        port_id: Optional[int] = None
    ):
        """
        Record a status event and adjust the charger's reliability score.
        """
        # 1. Record the audit event
        event = ChargerStatusEvent(
            charger_id=charger_id,
            port_id=port_id,
            status=status,
            source=source,
            confidence=confidence
        )
        db.add(event)

        # 2. Adjust the reliability score of the charger
        charger = await charger_repo.get(db, id=charger_id)
        if charger:
            current_score = cast(float, charger.reliability_score) or 0.5
            
            # Simple heuristic for No-IoT trust model (Playbook Phase 3)
            if source == "DRIVER_CHECKIN":
                # Check-in confirms it works
                setattr(charger, "reliability_score", min(1.0, current_score + 0.05))
            elif source == "DRIVER_CHECKOUT":
                # Complete session is strong proof
                setattr(charger, "reliability_score", min(1.0, current_score + 0.05))
            elif source == "DRIVER_REPORT":
                # Issue reported = penalize heavily
                setattr(charger, "reliability_score", max(0.0, current_score - 0.20))

            db.add(charger)

trust_service = TrustService()
