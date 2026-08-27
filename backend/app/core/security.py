"""
VoltEZ Core Security Module

JWT access/refresh token creation and validation, password hashing with Argon2.
"""

from datetime import UTC, datetime, timedelta

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings

# --- Password Hashing ---

pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")


def hash_password(password: str) -> str:
    """Hash a plaintext password using Argon2."""
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plaintext password against an Argon2 hash."""
    return pwd_context.verify(plain_password, hashed_password)


# --- JWT Tokens ---


def create_access_token(
    subject: str,
    role: str,
    expires_delta: timedelta | None = None,
) -> str:
    """
    Create a short-lived JWT access token.

    Args:
        subject: User ID (as string).
        role: User role for RBAC.
        expires_delta: Optional custom expiry. Defaults to config value.
    """
    if expires_delta is None:
        expires_delta = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    now = datetime.now(UTC)
    expire = now + expires_delta

    payload = {
        "sub": subject,
        "role": role,
        "type": "access",
        "iat": now,
        "exp": expire,
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_refresh_token(
    subject: str,
    expires_delta: timedelta | None = None,
) -> str:
    """
    Create a longer-lived JWT refresh token.

    Args:
        subject: User ID (as string).
        expires_delta: Optional custom expiry. Defaults to config value.
    """
    if expires_delta is None:
        expires_delta = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

    now = datetime.now(UTC)
    expire = now + expires_delta

    payload = {
        "sub": subject,
        "type": "refresh",
        "iat": now,
        "exp": expire,
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_token(token: str) -> dict:
    """
    Decode and validate a JWT token.

    Returns the decoded payload dict.
    Raises JWTError if token is invalid, expired, or malformed.
    """
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        return payload
    except JWTError:
        raise


def decode_access_token(token: str) -> dict:
    """
    Decode a token and verify it is an access token.

    Raises JWTError if invalid or wrong token type.
    """
    payload = decode_token(token)
    if payload.get("type") != "access":
        raise JWTError("Token is not an access token")
    return payload


def decode_refresh_token(token: str) -> dict:
    """
    Decode a token and verify it is a refresh token.

    Raises JWTError if invalid or wrong token type.
    """
    payload = decode_token(token)
    if payload.get("type") != "refresh":
        raise JWTError("Token is not a refresh token")
    return payload
