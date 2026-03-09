from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.api.dependencies import AdminAccess, DBSession
from app.db import crud
from app.schemas.access_key import AccessKeyConfigRead, AccessKeyCreate, AccessKeyRead

router = APIRouter(prefix="/access-keys")


@router.get("", response_model=list[AccessKeyRead])
def list_access_keys(_: AdminAccess, session: DBSession) -> list[AccessKeyRead]:
    return crud.list_access_keys(session)


@router.post("", response_model=AccessKeyRead, status_code=status.HTTP_201_CREATED)
def create_access_key(
    payload: AccessKeyCreate,
    _: AdminAccess,
    session: DBSession,
) -> AccessKeyRead:
    try:
        return crud.create_access_key(session, payload)
    except LookupError as error:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(error)) from error


@router.get("/{access_key_id}", response_model=AccessKeyRead)
def get_access_key(
    access_key_id: UUID,
    _: AdminAccess,
    session: DBSession,
) -> AccessKeyRead:
    access_key = crud.get_access_key(session, access_key_id)
    if access_key is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Access key not found")
    return access_key


@router.post("/{access_key_id}/deactivate", response_model=AccessKeyRead)
def deactivate_access_key(
    access_key_id: UUID,
    _: AdminAccess,
    session: DBSession,
) -> AccessKeyRead:
    access_key = crud.deactivate_access_key(session, access_key_id)
    if access_key is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Access key not found")
    return access_key


@router.get("/{access_key_id}/config", response_model=AccessKeyConfigRead)
def get_access_key_config(
    access_key_id: UUID,
    _: AdminAccess,
    session: DBSession,
) -> AccessKeyConfigRead:
    try:
        return crud.build_access_key_config(session, access_key_id)
    except LookupError as error:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(error)) from error
