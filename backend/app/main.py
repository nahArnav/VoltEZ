import time
import uuid
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.logging import setup_logging, get_logger
from app.core.errors import register_exception_handlers
from app.api.v1.router import api_router
from arq import create_pool
from arq.connections import RedisSettings
from contextlib import asynccontextmanager

# Initialize structured logging
setup_logging()
logger = get_logger("main")
from pathlib import Path
from voltez_ml.serving import AvailabilityPredictor, DemandPredictor

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Connecting to Redis for background tasks...")
    app.state.redis = await create_pool(RedisSettings.from_dsn(settings.REDIS_URL))
    
    logger.info("Loading ML models...")
    try:
        repo_root = Path(__file__).resolve().parents[2]
        demand_bundle = repo_root / "models" / "demand" / "voltez-demand-60m-pune-v1"
        availability_bundle = (
            repo_root / "models" / "availability" / "voltez-availability-pune-v1"
        )

        # Use the published, hash-verifying serving wrappers. The joblib files
        # contain dictionaries, not estimators that can be called directly.
        app.state.demand_model = DemandPredictor.from_artifact(
            demand_bundle,
            demand_bundle / "feature_contract.json",
        )
        app.state.availability_model = AvailabilityPredictor.from_artifact(
            availability_bundle,
            availability_bundle / "feature_contract.json",
        )
        app.state.ml_ready = True
        logger.info("ML models loaded successfully.")
    except Exception as e:
        logger.error(f"Failed to load ML models: {e}")
        app.state.demand_model = None
        app.state.availability_model = None
        app.state.ml_ready = False

    yield
    logger.info("Disconnecting from Redis...")
    await app.state.redis.close()

def create_app() -> FastAPI:
    # 1. Application Factory setup
    app = FastAPI(
        title=settings.PROJECT_NAME,
        version=settings.VERSION,
        openapi_url=f"{settings.API_V1_STR}/openapi.json",
        lifespan=lifespan  # <-- 🆕 ADD THIS LINE
    )

    # 2. CORS Middleware (Allows your frontend teammate to make requests without getting blocked)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # 3. Register standardized exception handlers
    register_exception_handlers(app)

    # 4. Request ID & Structured Logging Middleware
    @app.middleware("http")
    async def log_requests(request: Request, call_next):
        request_id = str(uuid.uuid4())
        # Store request_id in request state so error handlers can access it
        request.state.request_id = request_id
        start_time = time.time()

        # Process the actual request
        response = await call_next(request)

        # Calculate latency and log structured data
        process_time = time.time() - start_time
        logger.info(
            "request completed",
            extra={
                "request_id": request_id,
                "endpoint": request.url.path,
                "status_code": response.status_code,
                "latency": f"{process_time:.4f}s",
            }
        )

        response.headers["X-Request-ID"] = request_id
        return response

    # 5. Mount feature routers under /api/v1
    app.include_router(api_router, prefix=settings.API_V1_STR)

    # 6. System deployment endpoints
    @app.get("/health/live", tags=["System"])
    async def liveness():
        return {"status": "alive"}

    @app.get("/health/ready", tags=["System"])
    async def readiness(request: Request):
        return {
            "status": "ready",
            "ml_ready": getattr(request.app.state, "ml_ready", False)
        }

    @app.get("/version", tags=["System"])
    async def version():
        return {"version": settings.VERSION}

    return app


# Initialize the app
app = create_app()
