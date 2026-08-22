from fastapi import APIRouter
from .auth import router as auth_router
from .booking import router as booking_router
from .charger import router as charger_router
from .session import router as session_router

# This is the master router for version 1 of your API
api_router = APIRouter()

# Plug in the routes
api_router.include_router(auth_router)
api_router.include_router(booking_router)
api_router.include_router(charger_router)
api_router.include_router(session_router)