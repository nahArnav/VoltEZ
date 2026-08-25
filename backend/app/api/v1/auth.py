from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from jose import JWTError
from fastapi.security import OAuth2PasswordRequestForm

# Adjust the path to your get_db function if it's located elsewhere (e.g., app.core.database)
from app.db.session import get_db 
from app.schemas.user import UserCreate, UserResponse, UserLogin, TokenResponse, TokenRefresh
from app.services.auth import auth_service
from app.repositories.user import user_repo
from app.core.security import (
    create_access_token, 
    create_refresh_token, 
    decode_refresh_token
)

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(user_in: UserCreate, db: AsyncSession = Depends(get_db)):
    """Register a new user (Driver or Owner)."""
    user = await auth_service.register_user(db, user_in=user_in)
    return user


@router.post("/login", response_model=TokenResponse)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(), # <-- 🆕 Accept OAuth2 Form Data
    db: AsyncSession = Depends(get_db)
):
    """Authenticate a user and return JWT access and refresh tokens."""
    
    # 🆕 Use form_data.username (Swagger puts the email in the username field)
    user = await auth_service.authenticate_user(
        db, email=form_data.username, password=form_data.password
    )
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Generate tokens
    access_token = create_access_token(
        subject=str(user.id), 
        role=str(user.role.value if hasattr(user.role, 'value') else user.role)
    )
    refresh_token = create_refresh_token(subject=str(user.id))

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer"
    )

@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(token_in: TokenRefresh, db: AsyncSession = Depends(get_db)):
    """Use a valid refresh token to get a new access token."""
    try:
        payload = decode_refresh_token(token_in.refresh_token)
        sub = payload.get("sub")
        if not sub:
            raise HTTPException(status_code=401, detail="Invalid token payload")
        user_id = int(sub)
        
        user = await user_repo.get(db, id=user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User no longer exists.")
            
        new_access = create_access_token(
            subject=str(user.id), 
            role=str(user.role.value if hasattr(user.role, 'value') else user.role)
        )
        new_refresh = create_refresh_token(subject=str(user.id))
        
        return TokenResponse(
            access_token=new_access,
            refresh_token=new_refresh,
            token_type="bearer"
        )
        
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token.",
            headers={"WWW-Authenticate": "Bearer"},
        )