from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_db_session
from app.db import crud
from app.schemas.node import NodeCreate, NodeRead

router = APIRouter(prefix="/nodes")
DBSession = Depends(get_db_session)


@router.get("", response_model=list[NodeRead])  # noqa: B008
def list_nodes(session: Session = DBSession) -> list[NodeRead]:
    return crud.list_nodes(session)


@router.post("", response_model=NodeRead, status_code=status.HTTP_201_CREATED)  # noqa: B008
def create_node(payload: NodeCreate, session: Session = DBSession) -> NodeRead:
    return crud.create_node(session, payload)


@router.get("/{node_id}", response_model=NodeRead)  # noqa: B008
def get_node(node_id: UUID, session: Session = DBSession) -> NodeRead:
    node = crud.get_node(session, node_id)
    if node is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Node not found")
    return node
