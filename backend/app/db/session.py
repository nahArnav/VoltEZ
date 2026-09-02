from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import settings


def _get_async_database_url(url: str) -> str:
    """
    Convert a standard PostgreSQL URL to an asyncpg-compatible URL.
    Handles postgresql://, postgresql+psycopg://, and postgres:// formats.
    Also strips sslmode param (asyncpg uses its own ssl kwarg).
    """
    # Replace any sync driver prefix with asyncpg
    for prefix in ("postgresql+psycopg://", "postgresql://", "postgres://"):
        if url.startswith(prefix):
            url = url.replace(prefix, "postgresql+asyncpg://", 1)
            break
    # asyncpg doesn't understand sslmode=require in the DSN; strip it and
    # let the connect_args handle SSL instead.
    url = url.replace("?sslmode=require", "").replace("&sslmode=require", "")
    return url


def _needs_ssl(url: str) -> bool:
    """Detect cloud-hosted PostgreSQL that requires SSL (Neon, Supabase, etc.)."""
    cloud_hosts = (".neon.tech", ".supabase.co", ".render.com", ".railway.app", ".amazonaws.com")
    return any(host in url for host in cloud_hosts) or "sslmode=require" in settings.DATABASE_URL


import ssl as _ssl  # noqa: E402

_ssl_context = _ssl.create_default_context() if _needs_ssl(settings.DATABASE_URL) else None

# 1. Create the Async Engine
# This is the actual connection pool that talks to your PostgreSQL database.
engine = create_async_engine(
    _get_async_database_url(settings.DATABASE_URL),
    echo=False,
    future=True,
    **( {"connect_args": {"ssl": _ssl_context}} if _ssl_context else {} ),
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
