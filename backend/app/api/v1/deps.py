from app.schemas.enums import UserRole

"""
Shared FastAPI dependencies for authentication and authorization.

Used across all route files — never duplicate these in individual routers.
"""

from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode_access_token
from app.db.session import get_db
from app.repositories.user import user_repo
from database.models.user import User

# Looks for "Authorization: Bearer <token>" in the request header
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


async def get_current_user_id(token: str = Depends(oauth2_scheme)) -> UUID:
    """Extract and validate user ID from JWT access token."""
    try:
        payload = decode_access_token(token)
        user_id = payload.get("sub")
        if user_id is None:
            raise JWTError("Missing subject")
        return UUID(user_id)
    except (JWTError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_user(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Fetch the full User object for the authenticated user."""
    user = await user_repo.get(db, id=user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )
    return user


def require_role(*roles: UserRole):
    """
    Dependency factory: ensures the current user has one of the required roles.

    Usage:
        current_user: User = Depends(require_role(UserRole.OWNER, UserRole.ADMIN))
    """

    async def _check_role(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"This action requires one of: {[r.value for r in roles]}",
            )
        return current_user

    return _check_role
