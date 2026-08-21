from sqlalchemy import Boolean, String
from sqlalchemy.orm import Mapped, mapped_column

from database.base import Base


class ConnectorType(Base):
    __tablename__ = "connector_types"
    __table_args__ = {"schema": "app"}

    id: Mapped[int] = mapped_column(
        primary_key=True,
        autoincrement=True,
    )

    code: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        nullable=False,
    )

    display_name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    current_type: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
    )