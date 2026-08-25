import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession

# Import your FastAPI app and database dependency
from app.main import app
from app.db.session import get_db  # Using the correct path we found earlier!

TEST_DATABASE_URL = "postgresql+asyncpg://postgres:postgres@localhost:5432/voltez"

@pytest_asyncio.fixture(scope="function")
async def db_session():
    """
    Creates a fresh database session AND engine for each test, 
    preventing 'attached to a different loop' errors.
    """
    # 1. We moved the engine creation INSIDE the fixture!
    test_engine = create_async_engine(TEST_DATABASE_URL, echo=False)
    
    async with test_engine.connect() as connection:
        # Start a transaction
        transaction = await connection.begin()
        
        # Bind the session to the transaction
        async with AsyncSession(bind=connection, expire_on_commit=False) as session:
            yield session
            
        # The test is over. Rollback everything so the database stays clean!
        await transaction.rollback()
        
    # Safely shut down the engine after the test
    await test_engine.dispose()

@pytest_asyncio.fixture(scope="function")
async def client(db_session):
    """
    Creates a fake web browser to send requests to your FastAPI app.
    """
    async def override_get_db():
        yield db_session
        
    app.dependency_overrides[get_db] = override_get_db
    
    from asgi_lifespan import LifespanManager
    
    async with LifespanManager(app):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://testserver") as test_client:
            yield test_client
        
    app.dependency_overrides.clear()

pytest_plugins = ('pytest_asyncio',)