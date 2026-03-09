from collections.abc import Generator
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db import crud
from app.db.models import User
from app.db.session import SessionLocal


def get_db_session() -> Generator[Session, None, None]:
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


bearer_scheme = HTTPBearer(auto_error=False)


def require_admin_token(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> None:
    settings = get_settings()
    expected_token = settings.admin_api_token

    if credentials is None or credentials.credentials != expected_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin token",
            headers={"WWW-Authenticate": "Bearer"},
        )


def get_client_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    session: Annotated[Session, Depends(get_db_session)],
) -> User:
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid client token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = crud.get_user_by_client_token(session, credentials.credentials)
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid client token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


DBSession = Annotated[Session, Depends(get_db_session)]
AdminAccess = Annotated[None, Depends(require_admin_token)]
ClientUser = Annotated[User, Depends(get_client_user)]
