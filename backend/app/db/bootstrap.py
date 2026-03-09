from sqlalchemy import text

from app.db.session import engine


def apply_runtime_migrations() -> None:
    """Apply tiny safe migrations until Alembic is introduced."""
    if engine.dialect.name != "postgresql":
        return

    with engine.begin() as connection:
        connection.execute(text("ALTER TABLE nodes DROP CONSTRAINT IF EXISTS nodes_host_key"))
        connection.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_nodes_host_port "
                "ON nodes (host, port)"
            )
        )
