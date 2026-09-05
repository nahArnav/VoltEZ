import secrets
from dataclasses import dataclass
from typing import cast

from fastapi import HTTPException, status
from google.auth.exceptions import TransportError
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.core.config import settings
from app.core.security import hash_password, verify_password
from app.repositories.user import user_repo
from app.schemas.user import UserCreate
from database.models.user import User


@dataclass(frozen=True)
class GoogleIdentity:
    subject: str
    email: str
    name: str


class AuthService:
    @staticmethod
    async def register_user(db: AsyncSession, user_in: UserCreate) -> User:
        """Business logic for registering a new user."""

        # 1. Enforce business rule: Emails must be unique
        existing_user = await user_repo.get_by_email(db, email=user_in.email)
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="A user with this email already exists.",
            )

        # 2. Hash the plain-text password using your Argon2 function
        hashed_pwd = hash_password(user_in.password)

        # 3. Swap the plain text password out for the hashed one
        user_data = user_in.model_dump(exclude={"password"})
        user_data["password_hash"] = hashed_pwd

        # 4. Save to the database
        db_user = User(**user_data)
        db.add(db_user)
        await db.commit()
        await db.refresh(db_user)

        return db_user

    @staticmethod
    async def authenticate_user(db: AsyncSession, email: str, password: str) -> User | None:
        """Business logic for verifying a login attempt."""

        # 1. Look up the user in the database
        user = await user_repo.get_by_email(db, email=email)
        if not user:
            return None

        # 2. Verify the password matches the stored Argon2 hash
        password_hash = cast(str, user.password_hash)
        if not verify_password(password, password_hash):
            return None

        return user

    @staticmethod
    async def verify_google_id_token(id_token: str) -> GoogleIdentity:
        """Verify signature, issuer, expiry, and Web Client ID audience."""
        audience = settings.GOOGLE_WEB_CLIENT_ID.strip()
        if not audience:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Google authentication is not configured.",
            )

        def verify() -> dict:
            request = google_requests.Request()
            return google_id_token.verify_oauth2_token(id_token, request, audience)

        try:
            claims = await run_in_threadpool(verify)
        except TransportError as error:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Google authentication is temporarily unavailable.",
            ) from error
        except ValueError as error:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Google ID token.",
                headers={"WWW-Authenticate": "Bearer"},
            ) from error

        email = str(claims.get("email", "")).strip().lower()
        subject = str(claims.get("sub", "")).strip()
        email_verified = claims.get("email_verified")
        if not subject or not email or email_verified not in (True, "true", "True"):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Google account email is not verified.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        raw_name = str(claims.get("name", "")).strip()
        name = (raw_name or email.split("@", maxsplit=1)[0])[:150]
        return GoogleIdentity(subject=subject, email=email, name=name)

    @staticmethod
    async def find_or_create_google_user(
        db: AsyncSession,
        *,
        identity: GoogleIdentity,
        role: str,
    ) -> User:
        """Link by Google's verified email or provision a new VoltEZ user."""
        existing_user = await user_repo.get_by_email(db, email=identity.email)
        if existing_user:
            return existing_user

        # Google users never receive this generated password. Keeping an
        # unpredictable hash satisfies the current non-null user schema while
        # ensuring password login cannot be used for the social-only account.
        generated_password = secrets.token_urlsafe(48)
        user = User(
            name=identity.name,
            email=identity.email,
            password_hash=hash_password(generated_password),
            role=role,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
        return user


# Export a single instance to be used by the API endpoints later
auth_service = AuthService()
