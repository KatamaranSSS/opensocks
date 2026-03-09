from functools import lru_cache
from urllib.parse import quote_plus

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "OpenSocks API"
    app_version: str = "0.1.0"
    environment: str = "development"
    api_prefix: str = "/api/v1"
    database_url: str | None = None
    postgres_db: str | None = None
    postgres_user: str | None = None
    postgres_password: str | None = None
    postgres_host: str = "db"
    postgres_port: int = 5432

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    @property
    def resolved_database_url(self) -> str:
        if self.database_url:
            return self.database_url

        if self.postgres_db and self.postgres_user and self.postgres_password:
            encoded_password = quote_plus(self.postgres_password)
            return (
                f"postgresql+psycopg://{self.postgres_user}:{encoded_password}"
                f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
            )

        return "sqlite:///./opensocks.db"


@lru_cache
def get_settings() -> Settings:
    return Settings()
