from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class NodeCreate(BaseModel):
    name: str = Field(min_length=3, max_length=128)
    host: str = Field(min_length=3, max_length=255)
    port: int = Field(ge=1, le=65535)
    country_code: str | None = Field(default=None, min_length=2, max_length=2)
    is_active: bool = True


class NodeRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    host: str
    port: int
    country_code: str | None
    is_active: bool
    created_at: datetime
    updated_at: datetime
