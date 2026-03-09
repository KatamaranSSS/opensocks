from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_db_session
from app.db import crud
from app.schemas.user import UserCreate, UserRead

router = APIRouter(prefix="/users")


@router.get("", response_model=list[UserRead])
def list_users(session: Session = Depends(get_db_session)) -> list[UserRead]:
    return crud.list_users(session)


@router.post("", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def create_user(payload: UserCreate, session: Session = Depends(get_db_session)) -> UserRead:
    return crud.create_user(session, payload)


@router.get("/{user_id}", response_model=UserRead)
def get_user(user_id: UUID, session: Session = Depends(get_db_session)) -> UserRead:
    user = crud.get_user(session, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user
