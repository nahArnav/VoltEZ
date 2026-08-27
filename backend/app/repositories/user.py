from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.base import BaseRepository
from app.schemas.user import UserCreate, UserUpdate
from database.models.user import User


class RepositoryUser(BaseRepository[User, UserCreate, UserUpdate]):
    async def get_by_email(self, db: AsyncSession, email: str) -> User | None:
        """
        Fetch a user by their email address.
        Used for authentication and preventing duplicate registrations.
        """
        result = await db.execute(select(User).where(User.email == email))
        return result.scalar_one_or_none()

    # Note: We are inheriting create(), get(), get_multi(), update(), and remove()
    # directly from BaseRepository without needing to rewrite them!


# Create an instance of the repository to be imported and used across the app
user_repo = RepositoryUser(User)
