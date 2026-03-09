from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.api.dependencies import AdminAccess, DBSession
from app.db import crud
from app.schemas.node import NodeCreate, NodeRead

router = APIRouter(prefix="/nodes")


@router.get("", response_model=list[NodeRead])
def list_nodes(_: AdminAccess, session: DBSession) -> list[NodeRead]:
    return crud.list_nodes(session)


@router.post("", response_model=NodeRead, status_code=status.HTTP_201_CREATED)
def create_node(payload: NodeCreate, _: AdminAccess, session: DBSession) -> NodeRead:
    try:
        return crud.create_node(session, payload)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(error)) from error


@router.get("/{node_id}", response_model=NodeRead)
def get_node(node_id: UUID, _: AdminAccess, session: DBSession) -> NodeRead:
    node = crud.get_node(session, node_id)
    if node is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Node not found")
    return node
