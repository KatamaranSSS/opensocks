from sqlalchemy import text

from app.db.session import engine


def apply_runtime_migrations() -> None:
    """Apply tiny safe migrations until Alembic is introduced."""
    if engine.dialect.name != "postgresql":
        return

    with engine.begin() as connection:
        connection.execute(
            text(
                "ALTER TABLE users ADD COLUMN IF NOT EXISTS client_token VARCHAR(64)"
            )
        )
        connection.execute(
            text(
                "UPDATE users "
                "SET client_token = md5(random()::text || clock_timestamp()::text) "
                "WHERE client_token IS NULL"
            )
        )
        connection.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_users_client_token "
                "ON users (client_token)"
            )
        )
        connection.execute(text("ALTER TABLE nodes DROP CONSTRAINT IF EXISTS nodes_host_key"))
        connection.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_nodes_host_port "
                "ON nodes (host, port)"
            )
        )
