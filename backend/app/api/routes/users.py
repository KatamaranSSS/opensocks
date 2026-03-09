from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_db_session
from app.db import crud
from app.schemas.user import UserCreate, UserRead

router = APIRouter(prefix="/users")
DBSession = Depends(get_db_session)


@router.get("", response_model=list[UserRead])  # noqa: B008
def list_users(session: Session = DBSession) -> list[UserRead]:
    return crud.list_users(session)


@router.post("", response_model=UserRead, status_code=status.HTTP_201_CREATED)  # noqa: B008
def create_user(payload: UserCreate, session: Session = DBSession) -> UserRead:
    return crud.create_user(session, payload)


@router.get("/{user_id}", response_model=UserRead)  # noqa: B008
def get_user(user_id: UUID, session: Session = DBSession) -> UserRead:
    user = crud.get_user(session, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user
