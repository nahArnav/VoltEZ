"""
Alembic Environment Configuration

Configured for:
- Async SQLAlchemy engine (asyncpg)
- Auto-detection of all VoltEZ models via Base.metadata
- Database URL from environment (.env file)
- GeoAlchemy2/PostGIS column type support
"""

import asyncio
from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.ext.asyncio import async_engine_from_config

from alembic import context

# Load environment variables from .env
from dotenv import load_dotenv
import os

load_dotenv()

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Override sqlalchemy.url from environment variable
database_url = os.getenv("DATABASE_URL", "")
# Convert to asyncpg URL for migrations
for prefix in ("postgresql+psycopg://", "postgresql://"):
    if database_url.startswith(prefix):
        database_url = database_url.replace(prefix, "postgresql+asyncpg://", 1)
        break
config.set_main_option("sqlalchemy.url", database_url)

# Interpret the config file for Python logging.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Import all models so autogenerate can detect them
# This import triggers app/models/__init__.py which imports all model files
from app.models import Base  # noqa: E402

target_metadata = Base.metadata

# Include GeoAlchemy2 types in autogenerate
import geoalchemy2  # noqa: F401, E402


# PostGIS internal tables/schemas to exclude from autogenerate
EXCLUDE_SCHEMAS = {"tiger", "tiger_data", "topology"}

# PostGIS internal tables that live in the public schema
POSTGIS_INTERNAL_TABLES = {
    "spatial_ref_sys", "geometry_columns", "geography_columns",
    "raster_columns", "raster_overviews",
}


def include_name(name, type_, parent_names):
    """Filter autogenerate to only include VoltEZ application tables."""
    if type_ == "schema":
        return name not in EXCLUDE_SCHEMAS
    if type_ == "table":
        # Exclude PostGIS internal tables in public schema
        if name in POSTGIS_INTERNAL_TABLES:
            return False
        # Only include tables from the public schema (our app tables)
        schema = parent_names.get("schema_name", "public")
        return schema == "public"
    return True


def include_object(object, name, type_, reflected, compare_to):
    """Additional filter: exclude objects from PostGIS schemas."""
    if type_ == "table":
        schema = object.schema or "public"
        if schema in EXCLUDE_SCHEMAS:
            return False
        if name in POSTGIS_INTERNAL_TABLES:
            return False
    return True


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode.

    This configures the context with just a URL
    and not an Engine, though an Engine is acceptable
    here as well.  By skipping the Engine creation
    we don't even need a DBAPI to be available.

    Calls to context.execute() here emit the given string to the
    script output.
    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        include_name=include_name,
        include_object=include_object,
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection) -> None:
    """Run migrations with the given connection."""
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        include_name=include_name,
        include_object=include_object,
    )

    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """Run migrations in 'online' mode using async engine."""
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
