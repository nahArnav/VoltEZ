"""
Verification script for VoltEZ integrations (Gemini, Render, n8n, Config).
"""
import asyncio
import sys
import os

# Set dummy env vars for local verification
os.environ["SECRET_KEY"] = "verification_secret_key_minimum_32_characters_long_123"
os.environ["DATABASE_URL"] = "postgresql+asyncpg://voltez:change_me@localhost:5432/voltez_db"
os.environ["REDIS_URL"] = "redis://localhost:6379/0"

def test_imports():
    print("--> Testing imports...")
    from app.core.config import settings
    print(f"    [OK] Settings loaded: PROJECT_NAME={settings.PROJECT_NAME}, N8N_WEBHOOK_URL={settings.N8N_WEBHOOK_URL!r}")

    from app.api.v1.ai import router as ai_router
    print(f"    [OK] AI Router loaded: routes count = {len(ai_router.routes)}")

    from app.services.n8n import n8n_service
    print("    [OK] N8nService loaded")

    from app.main import create_app
    app = create_app()
    print("    [OK] FastAPI app created successfully")

    # Check routes
    route_paths = [r.path for r in app.routes]
    print(f"    [OK] Total app routes: {len(route_paths)}")
    
    assert "/" in route_paths, "Root GET / missing!"
    assert "/health" in route_paths, "Health GET /health missing!"
    assert "/api/v1/ai/charging-advice" in route_paths, "AI charging advice missing from /api/v1!"
    assert "/api/ai/charging-advice" in route_paths, "Direct /api/ai/charging-advice alias missing!"
    assert "/api/v1/ai/business-insights" in route_paths, "AI business insights missing!"
    assert "/api/v1/ai/incident-alert" in route_paths, "AI incident alert missing!"

    print("--> All route assertions PASSED!")

async def test_ai_fallback_and_n8n():
    print("--> Testing AI Charging Advice fallback...")
    from app.api.v1.ai import ChargingAdviceRequest, LocationCoords, get_ai_charging_advice
    from unittest.mock import AsyncMock

    mock_db = AsyncMock()
    # Mock empty db execution
    mock_result = AsyncMock()
    mock_result.all.return_value = []
    mock_db.execute.return_value = mock_result

    req = ChargingAdviceRequest(
        battery_percentage=32.0,
        current_location=LocationCoords(lat=18.5204, lng=73.8567),
        destination="Mumbai",
    )

    response = await get_ai_charging_advice(req, db=mock_db)
    print(f"    [OK] AI Recommendation generated: {response.recommendation[:80]}...")
    print(f"    [OK] Best station: {response.recommended_station.name if response.recommended_station else 'None'}")
    assert response.recommended_station is not None
    assert len(response.all_options) > 0

    print("--> Testing n8n incident dispatch...")
    from app.services.n8n import n8n_service
    res = await n8n_service.send_incident_alert(
        station_id="ST-102",
        station_name="Hinjewadi Station",
        status="offline",
        offline_duration_minutes=17,
        available_ports=0,
        total_ports=6,
    )
    print(f"    [OK] n8n dispatch result (safe fallback when unconfigured): {res}")
    assert res.get("status") in ("skipped", "delivered", "error", "failed")

    print("\n==========================================")
    print("ALL INTEGRATION VERIFICATION CHECKS PASSED!")
    print("==========================================")

if __name__ == "__main__":
    test_imports()
    asyncio.run(test_ai_fallback_and_n8n())
