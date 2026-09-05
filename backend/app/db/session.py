from collections.abc import AsyncGenerator
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import settings


def _get_async_database_url(url: str) -> str:
    """
    Convert a standard PostgreSQL URL to an asyncpg-compatible URL.
    Handles postgresql://, postgresql+psycopg://, and postgres:// formats.
    Also strips libpq-only SSL parameters (asyncpg receives an SSL context
    through connect_args instead).
    """
    # Replace any sync driver prefix with asyncpg
    for prefix in ("postgresql+psycopg://", "postgresql://", "postgres://"):
        if url.startswith(prefix):
            url = url.replace(prefix, "postgresql+asyncpg://", 1)
            break
    parts = urlsplit(url)
    query = [
        (key, value)
        for key, value in parse_qsl(parts.query, keep_blank_values=True)
        if key not in {"sslmode", "channel_binding"}
    ]
    return urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment))


def _needs_ssl(url: str) -> bool:
    """Detect cloud-hosted PostgreSQL that requires SSL (Neon, Supabase, etc.)."""
    cloud_hosts = (".neon.tech", ".supabase.co", ".render.com", ".railway.app", ".amazonaws.com")
    return any(host in url for host in cloud_hosts) or "sslmode=require" in settings.DATABASE_URL


import ssl as _ssl  # noqa: E402

_ssl_context = _ssl.create_default_context() if _needs_ssl(settings.DATABASE_URL) else None

_connect_args: dict[str, object] = {
    "timeout": float(settings.DB_CONNECT_TIMEOUT_SECONDS),
}
if _ssl_context is not None:
    _connect_args["ssl"] = _ssl_context

# 1. Create the Async Engine
# This is the actual connection pool that talks to your PostgreSQL database.
engine = create_async_engine(
    _get_async_database_url(settings.DATABASE_URL),
    echo=False,
    future=True,
    # Neon, Render Postgres and other managed providers can close an idle
    # socket. Validate pooled connections before handing them to a request so
    # users never receive asyncpg's "connection is closed" failure.
    pool_pre_ping=True,
    pool_recycle=settings.DB_POOL_RECYCLE_SECONDS,
    pool_timeout=settings.DB_POOL_TIMEOUT_SECONDS,
    pool_size=settings.DB_POOL_SIZE,
    max_overflow=settings.DB_MAX_OVERFLOW,
    pool_use_lifo=True,
    connect_args=_connect_args,
)

# 2. Create the Session Factory
# This generates new database sessions whenever we need them.
AsyncSessionLocal = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)


# 3. The Request-Scoped Dependency
# This is the magic function we will inject into our API endpoints.
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
