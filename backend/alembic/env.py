import os
from logging.config import fileConfig

from dotenv import load_dotenv
from sqlalchemy import create_engine, pool

import database.models  # noqa: F401
from alembic import context
from database.base_class import Base

load_dotenv()

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL is not set")

assert isinstance(DATABASE_URL, str)

if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+psycopg://", 1)
elif DATABASE_URL.startswith("postgresql+asyncpg://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql+asyncpg://", "postgresql+psycopg://", 1)
elif DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg://", 1)

target_metadata = Base.metadata



def include_name(name, type_, parent_names):
    if type_ == "schema":
        return name in {"app", "analytics", "ml_lab"}

    if type_ == "table":
        schema = parent_names.get("schema_name")
        return schema in {"app", "analytics", "ml_lab"}

    return True


def run_migrations_offline() -> None:
    context.configure(
        url=DATABASE_URL,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        include_schemas=True,
        include_name=include_name,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    # Cloud-hosted databases (Neon, Supabase) require SSL
    connect_args = {}
    cloud_hosts = (".neon.tech", ".supabase.co", ".render.com", ".railway.app")
    if any(host in (DATABASE_URL or "") for host in cloud_hosts):
        connect_args["sslmode"] = "require"

    connectable = create_engine(
        DATABASE_URL,
        poolclass=pool.NullPool,
        connect_args=connect_args,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            include_schemas=True,
            include_name=include_name,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
