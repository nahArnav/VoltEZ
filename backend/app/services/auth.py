from typing import Optional, cast
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status

from app.models.user import User
from app.schemas.user import UserCreate
from app.repositories.user import user_repo
from app.core.security import hash_password, verify_password

class AuthService:
    
    @staticmethod
    async def register_user(db: AsyncSession, user_in: UserCreate) -> User:
        """Business logic for registering a new user."""
        
        # 1. Enforce business rule: Emails must be unique
        existing_user = await user_repo.get_by_email(db, email=user_in.email)
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="A user with this email already exists."
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
    async def authenticate_user(db: AsyncSession, email: str, password: str) -> Optional[User]:
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

# Export a single instance to be used by the API endpoints later
auth_service = AuthService()