import time
import logging
import uuid
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.v1.router import api_router

# Setup basic structured logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_app() -> FastAPI:
    # 1. Application Factory setup
    app = FastAPI(
        title=settings.PROJECT_NAME,
        version=settings.VERSION,
        openapi_url=f"{settings.API_V1_STR}/openapi.json"
    )

    # 2. CORS Middleware (Allows your frontend teammate to make requests without getting blocked)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"], # Note: Restrict this to your frontend URL before production
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # 3. Request ID & Structured Logging Middleware
    @app.middleware("http")
    async def log_requests(request: Request, call_next):
        request_id = str(uuid.uuid4())
        start_time = time.time()
        
        # Process the actual request
        response = await call_next(request)
        
        # Calculate latency and log structured data
        process_time = time.time() - start_time
        logger.info(
            f"request_id={request_id} endpoint={request.url.path} "
            f"status={response.status_code} latency={process_time:.4f}s"
        )
        
        response.headers["X-Request-ID"] = request_id
        return response

    # 4. Mount feature routers under /api/v1
    app.include_router(api_router, prefix=settings.API_V1_STR)

    # 5. System deployment endpoints
    @app.get("/health/live", tags=["System"])
    async def liveness():
        return {"status": "alive"}

    @app.get("/health/ready", tags=["System"])
    async def readiness():
        return {"status": "ready"}

    @app.get("/version", tags=["System"])
    async def version():
        return {"version": settings.VERSION}

    return app

# Initialize the app
app = create_app()