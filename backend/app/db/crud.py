from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Node, User
from app.schemas.node import NodeCreate
from app.schemas.user import UserCreate


def list_users(session: Session) -> list[User]:
    return list(session.scalars(select(User).order_by(User.created_at.desc())))


def get_user(session: Session, user_id: UUID) -> User | None:
    return session.get(User, str(user_id))


def create_user(session: Session, payload: UserCreate) -> User:
    user = User(
        username=payload.username,
        email=payload.email,
        is_active=payload.is_active,
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


def list_nodes(session: Session) -> list[Node]:
    return list(session.scalars(select(Node).order_by(Node.created_at.desc())))


def get_node(session: Session, node_id: UUID) -> Node | None:
    return session.get(Node, str(node_id))


def create_node(session: Session, payload: NodeCreate) -> Node:
    node = Node(
        name=payload.name,
        host=payload.host,
        port=payload.port,
        country_code=payload.country_code,
        is_active=payload.is_active,
    )
    session.add(node)
    session.commit()
    session.refresh(node)
    return node
