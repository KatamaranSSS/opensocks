from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.api.dependencies import AdminAccess, DBSession
from app.db import crud
from app.schemas.user import UserCreate, UserRead

router = APIRouter(prefix="/users")


@router.get("", response_model=list[UserRead])
def list_users(_: AdminAccess, session: DBSession) -> list[UserRead]:
    return crud.list_users(session)


@router.post("", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def create_user(payload: UserCreate, _: AdminAccess, session: DBSession) -> UserRead:
    try:
        return crud.create_user(session, payload)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(error)) from error


@router.get("/{user_id}", response_model=UserRead)
def get_user(user_id: UUID, _: AdminAccess, session: DBSession) -> UserRead:
    user = crud.get_user(session, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user
