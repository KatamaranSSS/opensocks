from fastapi import APIRouter

from app.api.routes.access_keys import router as access_keys_router
from app.api.routes.client import router as client_router
from app.api.routes.health import router as health_router
from app.api.routes.nodes import router as nodes_router
from app.api.routes.users import router as users_router

api_router = APIRouter()
api_router.include_router(health_router, tags=["health"])
api_router.include_router(users_router, tags=["users"])
api_router.include_router(nodes_router, tags=["nodes"])
api_router.include_router(access_keys_router, tags=["access-keys"])
api_router.include_router(client_router, tags=["client"])
