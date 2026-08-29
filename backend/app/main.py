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
from pathlib import Path

# Initialize structured logging
setup_logging()
logger = get_logger("main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # --- Redis connection for booking holds and background jobs ---
    logger.info("Connecting to Redis for background tasks...")
    app.state.redis = await create_pool(RedisSettings.from_dsn(settings.REDIS_URL))

    # --- Load ML models with SHA-256 hash verification ---
    from app.ml.model_loader import load_model_bundle

    base_dir = Path(__file__).parent.parent.parent.parent
    models_dir = base_dir / "models"

    demand_bundle = None
    availability_bundle = None

    try:
        demand_dir = models_dir / "demand" / "voltez-demand-60m-pune-v1"
        demand_bundle = load_model_bundle(demand_dir, strict_hash=True)
        logger.info(
            "[ML] Demand model loaded: id=%s, stage=%s, features=%d",
            demand_bundle.model_id,
            demand_bundle.stage,
            demand_bundle.feature_count,
        )
    except Exception as e:
        logger.error("[ML] Failed to load demand model: %s", e)

    try:
        avail_dir = models_dir / "availability" / "voltez-availability-pune-v1"
        availability_bundle = load_model_bundle(avail_dir, strict_hash=True)
        logger.info(
            "[ML] Availability model loaded: id=%s, stage=%s, features=%d",
            availability_bundle.model_id,
            availability_bundle.stage,
            availability_bundle.feature_count,
        )
    except Exception as e:
        logger.error("[ML] Failed to load availability model: %s", e)

    # Wire loaded bundles into the MLAdapter singleton
    from app.ml.adapters import ml_adapter

    if demand_bundle is not None:
        ml_adapter.load_demand_model(demand_bundle)
    if availability_bundle is not None:
        ml_adapter.load_availability_model(availability_bundle)

    # Store bundles on app.state for access by health endpoints
    app.state.demand_bundle = demand_bundle
    app.state.availability_bundle = availability_bundle
    app.state.ml_ready = demand_bundle is not None or availability_bundle is not None

    if app.state.ml_ready:
        logger.info("[ML] At least one model loaded. ml_ready=true.")
    else:
        logger.warning("[ML] No models loaded. Falling back to heuristics.")

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
        demand_bundle = getattr(request.app.state, "demand_bundle", None)
        avail_bundle = getattr(request.app.state, "availability_bundle", None)
        return {
            "status": "ready",
            "ml_ready": getattr(request.app.state, "ml_ready", False),
            "models": {
                "demand": {
                    "loaded": demand_bundle is not None,
                    "model_id": demand_bundle.model_id if demand_bundle else None,
                    "stage": demand_bundle.stage if demand_bundle else None,
                    "features": demand_bundle.feature_count if demand_bundle else 0,
                    "hash_prefix": demand_bundle.artifact_hash[:16] if demand_bundle else None,
                },
                "availability": {
                    "loaded": avail_bundle is not None,
                    "model_id": avail_bundle.model_id if avail_bundle else None,
                    "stage": avail_bundle.stage if avail_bundle else None,
                    "features": avail_bundle.feature_count if avail_bundle else 0,
                    "hash_prefix": avail_bundle.artifact_hash[:16] if avail_bundle else None,
                },
            },
        }

    @app.get("/version", tags=["System"])
    async def version():
        return {"version": settings.VERSION}

    return app


# Initialize the app
app = create_app()