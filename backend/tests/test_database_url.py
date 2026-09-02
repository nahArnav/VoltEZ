from app.db.session import _get_async_database_url


def test_neon_database_url_removes_libpq_only_ssl_parameters() -> None:
    source = (
        "postgresql://user:password@example.neon.tech/neondb"
        "?sslmode=require&channel_binding=require"
    )

    result = _get_async_database_url(source)

    assert result == "postgresql+asyncpg://user:password@example.neon.tech/neondb"


def test_database_url_preserves_supported_query_parameters() -> None:
    source = (
        "postgresql+psycopg://user:password@db.example.com/voltez"
        "?application_name=voltez&sslmode=require"
    )

    result = _get_async_database_url(source)

    assert result == (
        "postgresql+asyncpg://user:password@db.example.com/voltez"
        "?application_name=voltez"
    )
