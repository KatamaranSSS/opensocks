from uuid import UUID

from fastapi import APIRouter

from app.api.dependencies import ClientUser, DBSession
from app.db import crud
from app.schemas.user import UserConfigBundleRead

router = APIRouter(prefix="/client")


@router.get("/bootstrap", response_model=UserConfigBundleRead)
def client_bootstrap(current_user: ClientUser, session: DBSession) -> UserConfigBundleRead:
    return crud.build_user_config_bundle(session, UUID(current_user.id))
