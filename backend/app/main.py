from fastapi import FastAPI

from app.api.routes import api_router
from app.core.config import get_settings
from app.db.base import Base
from app.db.session import engine


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
    )
    app.include_router(api_router, prefix=settings.api_prefix)

    @app.on_event("startup")
    def create_database_tables() -> None:
        Base.metadata.create_all(bind=engine)

    return app


app = create_app()
