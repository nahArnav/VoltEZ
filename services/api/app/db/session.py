from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from typing import AsyncGenerator
from app.core.config import settings

# 1. Create the Async Engine
# This is the actual connection pool that talks to your PostgreSQL database.
engine = create_async_engine(
    settings.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://"), 
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