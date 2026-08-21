from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass

from database.models.user import User  # noqa: E402,F401