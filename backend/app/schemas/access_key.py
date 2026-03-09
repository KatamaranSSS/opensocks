from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class AccessKeyCreate(BaseModel):
    name: str = Field(min_length=3, max_length=128)
    user_id: UUID
    node_id: UUID
    cipher: str = Field(default="chacha20-ietf-poly1305", min_length=3, max_length=64)
    secret: str | None = Field(default=None, min_length=8, max_length=255)
    is_active: bool = True


class AccessKeyRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    user_id: UUID
    node_id: UUID
    cipher: str
    secret: str
    is_active: bool
    created_at: datetime
    updated_at: datetime


class AccessKeyConfigRead(BaseModel):
    access_key_id: UUID
    name: str
    server: str
    server_port: int
    method: str
    password: str
    tag: str
    ss_url: str
