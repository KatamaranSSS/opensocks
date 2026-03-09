from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.schemas.access_key import AccessKeyConfigRead


class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=64)
    email: EmailStr | None = None
    is_active: bool = True


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    username: str
    email: EmailStr | None
    is_active: bool
    created_at: datetime
    updated_at: datetime


class UserConfigBundleRead(BaseModel):
    user_id: UUID
    username: str
    configs: list[AccessKeyConfigRead]
