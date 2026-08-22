from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from typing import AsyncGenerator
from app.core.config import settings


def _get_async_database_url(url: str) -> str:
    """
    Convert a standard PostgreSQL URL to an asyncpg-compatible URL.
    Handles both postgresql:// and postgresql+psycopg:// formats.
    """
    # Replace any sync driver prefix with asyncpg
    for prefix in ("postgresql+psycopg://", "postgresql://"):
        if url.startswith(prefix):
            return url.replace(prefix, "postgresql+asyncpg://", 1)
    return url


# 1. Create the Async Engine
# This is the actual connection pool that talks to your PostgreSQL database.
engine = create_async_engine(
    _get_async_database_url(settings.DATABASE_URL),
    echo=False,
    future=True
)

# 2. Create the Session Factory
# This generates new database sessions whenever we need them.
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False
)


# 3. The Request-Scoped Dependency
# This is the magic function we will inject into our API endpoints.
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()