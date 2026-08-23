import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession

# Import your FastAPI app and database dependency
from app.main import app
from app.db.session import get_db 

#run tests from local terminal (outside Docker)
# we point to localhost on port 5432
TEST_DATABASE_URL = "postgresql+asyncpg://postgres:postgres@localhost:5432/voltez"

# 1. Create a dedicated engine for testing
test_engine = create_async_engine(TEST_DATABASE_URL, echo=False)

@pytest_asyncio.fixture(scope="function")
async def db_session():
    """
    Creates a fresh database session for a test and rolls back changes after.
    This guarantees that tests NEVER save dirty data to your real database.
    """
    async with test_engine.connect() as connection:
        # Start a transaction
        transaction = await connection.begin()
        
        # Bind the session to the transaction
        async with AsyncSession(bind=connection, expire_on_commit=False) as session:
            yield session
            
        # The test is over. Rollback everything so the database stays clean!
        await transaction.rollback()

@pytest_asyncio.fixture(scope="function")
async def client(db_session):
    """
    Creates a fake web browser (AsyncClient) to send requests to your FastAPI app.
    It intercepts the database dependency so the API uses our rollback session.
    """
    # Create the override function
    async def override_get_db():
        yield db_session
        
    # Swap out the real get_db with our test version
    app.dependency_overrides[get_db] = override_get_db
    
    # Use httpx to create an async client that acts like a mobile app calling your API
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://testserver") as test_client:
        yield test_client
        
    # Clean up the override when the test finishes
    app.dependency_overrides.clear()

# Tell pytest we are using async/await syntax
pytest_plugins = ('pytest_asyncio',)