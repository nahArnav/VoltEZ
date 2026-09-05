import asyncio
import time
import uuid
from contextlib import asynccontextmanager
from pathlib import Path

import httpx
from arq import create_pool
from arq.connections import RedisSettings
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.errors import register_exception_handlers
from app.core.logging import get_logger, setup_logging
from app.db.session import engine

# Initialize structured logging
setup_logging()
logger = get_logger("main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # --- Redis connection for booking holds and background jobs ---
    logger.info("Connecting to Redis for background tasks...")
    app.state.redis = await create_pool(RedisSettings.from_dsn(settings.REDIS_URL))

    # Reuse outbound TCP/TLS connections for Google, Gemini and Tavily calls.
    # Creating a new HTTP client for every mobile request adds avoidable
    # handshakes and is especially visible from a single-instance deployment.
    app.state.http_client = httpx.AsyncClient(
        timeout=httpx.Timeout(12.0, connect=5.0, pool=2.0),
        limits=httpx.Limits(
            max_connections=40,
            max_keepalive_connections=20,
            keepalive_expiry=30.0,
        ),
        headers={
            "User-Agent": "VoltEZ-Backend/1.0 (+https://voltez.arnavpatidar.com)",
        },
    )

    # --- Load ML models with SHA-256 hash verification ---
    from app.ml.model_loader import load_model_bundle

    # main.py lives at <repo>/backend/app/main.py; the model bundles live at
    # <repo>/backend/models. Four parents would escape the repository and
    # silently force every request onto heuristic fallbacks.
    base_dir = Path(__file__).resolve().parents[1]
    models_dir = base_dir / "models"

    demand_bundle = None
    availability_bundle = None
    waiting_bundle = None
    reliability_bundle = None

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

    def load_optional_bundle(model_family: str):
        family_dir = models_dir / model_family
        if not family_dir.exists():
            logger.warning("[ML] No packaged %s model; calibrated fallback enabled.", model_family)
            return None
        candidates = sorted(
            path for path in family_dir.iterdir() if (path / "deployment_manifest.json").exists()
        )
        if not candidates:
            logger.warning(
                "[ML] No deployable %s bundle; calibrated fallback enabled.", model_family
            )
            return None
        try:
            return load_model_bundle(candidates[-1], strict_hash=True)
        except Exception as exc:
            logger.error("[ML] Failed to load %s model: %s", model_family, exc)
            return None

    waiting_bundle = load_optional_bundle("waiting_time")
    reliability_bundle = load_optional_bundle("reliability")

    # Wire loaded bundles into the MLAdapter singleton
    from app.ml.adapters import ml_adapter

    if demand_bundle is not None:
        ml_adapter.load_demand_model(demand_bundle)
    if availability_bundle is not None:
        ml_adapter.load_availability_model(availability_bundle)
    ml_adapter.load_waiting_time_model(waiting_bundle)
    ml_adapter.load_reliability_model(reliability_bundle)

    # Store bundles on app.state for access by health endpoints
    app.state.demand_bundle = demand_bundle
    app.state.availability_bundle = availability_bundle
    app.state.waiting_bundle = waiting_bundle
    app.state.reliability_bundle = reliability_bundle
    # Both core models are required for a production-ready instance. Individual
    # predictors still retain their documented heuristic fallback when a model
    # is unavailable in development, but readiness must fail closed so a
    # deployment cannot silently serve degraded ML results.
    app.state.ml_ready = demand_bundle is not None and availability_bundle is not None

    if app.state.ml_ready:
        logger.info("[ML] Demand and availability models loaded. ml_ready=true.")
    else:
        logger.warning("[ML] One or more core models missing. Heuristic fallback remains enabled.")

    try:
        yield
    finally:
        logger.info("Closing backend connection pools...")
        await app.state.redis.aclose()
        await app.state.http_client.aclose()
        await engine.dispose()


def create_app() -> FastAPI:
    # 1. Application Factory setup
    app = FastAPI(
        title=settings.PROJECT_NAME,
        version=settings.VERSION,
        openapi_url=f"{settings.API_V1_STR}/openapi.json",
        lifespan=lifespan,  # <-- 🆕 ADD THIS LINE
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
            },
        )

        response.headers["X-Request-ID"] = request_id
        return response

    # 5. Mount feature routers under /api/v1
    app.include_router(api_router, prefix=settings.API_V1_STR)

    # 5b. Mount /api/ai alias for direct compatibility with external integrations
    from app.api.v1.ai import router as direct_ai_router

    app.include_router(direct_ai_router, prefix="/api")

    # 6. System deployment endpoints
    @app.get("/", tags=["System"])
    async def root():
        return {
            "status": "ok",
            "service": settings.PROJECT_NAME,
            "version": settings.VERSION,
            "environment": settings.ENVIRONMENT,
        }

    @app.get("/health", tags=["System"])
    async def health():
        return {"status": "ok"}

    @app.get("/health/live", tags=["System"])
    async def liveness():
        return {"status": "alive"}

    @app.get("/health/ready", tags=["System"])
    async def readiness(request: Request):
        async def probe_database() -> None:
            async with engine.connect() as connection:
                await connection.execute(text("SELECT 1"))

        async def probe_redis() -> None:
            redis = getattr(request.app.state, "redis", None)
            if redis is None:
                raise RuntimeError("Redis pool is not initialized")
            await redis.ping()

        async def probe_worker() -> None:
            redis = getattr(request.app.state, "redis", None)
            if redis is None:
                raise RuntimeError("Redis pool is not initialized")
            if not await redis.exists(settings.WORKER_HEALTH_CHECK_KEY):
                raise RuntimeError("ARQ worker heartbeat is missing")

        # Keep the probe bounded: a failed dependency must produce a quick,
        # actionable 503 rather than tying up health-check workers.
        async def run_probe(name, probe):
            try:
                await asyncio.wait_for(probe(), timeout=2.0)
            except Exception as exc:
                logger.warning("Readiness check failed for %s: %s", name, exc)
                return name, False, str(exc)
            return name, True, None

        # Dependency failures should take at most the slowest probe timeout,
        # not the sum of every timeout.
        probes = [
            run_probe("database", probe_database),
            run_probe("redis", probe_redis),
        ]
        if settings.ENVIRONMENT.lower() == "production":
            probes.append(run_probe("worker", probe_worker))
        probe_results = await asyncio.gather(*probes)
        checks = {name: healthy for name, healthy, _error in probe_results}
        check_errors = {name: error for name, _healthy, error in probe_results if error is not None}

        demand_bundle = getattr(request.app.state, "demand_bundle", None)
        avail_bundle = getattr(request.app.state, "availability_bundle", None)
        waiting_bundle = getattr(request.app.state, "waiting_bundle", None)
        reliability_bundle = getattr(request.app.state, "reliability_bundle", None)
        checks["ml"] = bool(getattr(request.app.state, "ml_ready", False))
        is_ready = all(value is True for value in checks.values())
        payload = {
            "status": "ready" if is_ready else "not_ready",
            "checks": checks,
            "errors": check_errors,
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
                "waiting_time": {
                    "loaded": waiting_bundle is not None,
                    "model_id": waiting_bundle.model_id if waiting_bundle else None,
                    "source": "artifact" if waiting_bundle else "synthetic-calibrated-fallback",
                },
                "reliability": {
                    "loaded": reliability_bundle is not None,
                    "model_id": reliability_bundle.model_id if reliability_bundle else None,
                    "source": (
                        "artifact" if reliability_bundle else "synthetic-calibrated-fallback"
                    ),
                },
            },
        }
        return JSONResponse(status_code=200 if is_ready else 503, content=payload)

    @app.get("/version", tags=["System"])
    async def version():
        return {"version": settings.VERSION}

    return app


# Initialize the app
app = create_app()
