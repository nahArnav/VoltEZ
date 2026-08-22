from fastapi import APIRouter

api_router = APIRouter()

# Basic health endpoint for the v1 API
@api_router.get("/health")

async def health_check():
    return {"status": "ok", "message": "VoltEZ API v1 is running"}