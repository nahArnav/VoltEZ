from fastapi import APIRouter

from .analytics import router as analytics_router
from .auth import router as auth_router
from .availability import router as availability_router
from .booking import router as booking_router
from .businesses import router as businesses_router
from .charger import router as charger_router
from .payments import router as payments_router
from .recommendations import router as recommendations_router
from .session import router as session_router
from .users import router as users_router
from .vehicles import router as vehicles_router
from .ws import router as ws_router

# This is the master router for version 1 of your API
api_router = APIRouter()

# Plug in the routes
api_router.include_router(auth_router)
api_router.include_router(booking_router)
api_router.include_router(charger_router)
api_router.include_router(session_router)
api_router.include_router(users_router)
api_router.include_router(vehicles_router)
api_router.include_router(businesses_router)
api_router.include_router(recommendations_router)
api_router.include_router(availability_router)
api_router.include_router(payments_router)
api_router.include_router(ws_router)
api_router.include_router(analytics_router)
