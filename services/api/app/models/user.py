from sqlalchemy import Column, Integer, String, DateTime, Enum
from sqlalchemy.sql import func
import enum
from app.models.base import Base

# Define the exact roles required by the playbook
class UserRole(str, enum.Enum):
    DRIVER = "DRIVER"
    OWNER = "OWNER"
    ADMIN = "ADMIN"

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    role = Column(Enum(UserRole), default=UserRole.DRIVER, nullable=False)
    verification_status = Column(String, default="unverified")
    created_at = Column(DateTime(timezone=True), server_default=func.now())