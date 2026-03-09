from base64 import urlsafe_b64encode
from secrets import token_hex
from urllib.parse import quote
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.models import AccessKey, Node, User
from app.schemas.access_key import AccessKeyConfigRead, AccessKeyCreate
from app.schemas.node import NodeCreate
from app.schemas.user import UserClientTokenRead, UserConfigBundleRead, UserCreate


def list_users(session: Session) -> list[User]:
    return list(session.scalars(select(User).order_by(User.created_at.desc())))


def get_user(session: Session, user_id: UUID) -> User | None:
    return session.get(User, str(user_id))


def create_user(session: Session, payload: UserCreate) -> User:
    duplicate_username = session.scalar(select(User).where(User.username == payload.username))
    if duplicate_username is not None:
        raise ValueError("Username already exists")

    user = User(
        username=payload.username,
        email=payload.email,
        client_token=token_hex(24),
        is_active=payload.is_active,
    )
    session.add(user)
    try:
        session.commit()
    except IntegrityError as error:
        session.rollback()
        raise ValueError("User violates uniqueness constraints") from error
    session.refresh(user)
    return user


def list_nodes(session: Session) -> list[Node]:
    return list(session.scalars(select(Node).order_by(Node.created_at.desc())))


def get_node(session: Session, node_id: UUID) -> Node | None:
    return session.get(Node, str(node_id))


def create_node(session: Session, payload: NodeCreate) -> Node:
    duplicate_name = session.scalar(select(Node).where(Node.name == payload.name))
    if duplicate_name is not None:
        raise ValueError("Node name already exists")

    duplicate_endpoint = session.scalar(
        select(Node).where(Node.host == payload.host, Node.port == payload.port)
    )
    if duplicate_endpoint is not None:
        raise ValueError("Node endpoint already exists")

    node = Node(
        name=payload.name,
        host=payload.host,
        port=payload.port,
        country_code=payload.country_code,
        is_active=payload.is_active,
    )
    session.add(node)
    try:
        session.commit()
    except IntegrityError as error:
        session.rollback()
        raise ValueError("Node violates uniqueness constraints") from error
    session.refresh(node)
    return node


def list_access_keys(session: Session) -> list[AccessKey]:
    return list(session.scalars(select(AccessKey).order_by(AccessKey.created_at.desc())))


def get_access_key(session: Session, access_key_id: UUID) -> AccessKey | None:
    return session.get(AccessKey, str(access_key_id))


def create_access_key(session: Session, payload: AccessKeyCreate) -> AccessKey:
    duplicate_name = session.scalar(select(AccessKey).where(AccessKey.name == payload.name))
    if duplicate_name is not None:
        raise ValueError("Access key name already exists")

    user = session.get(User, str(payload.user_id))
    if user is None:
        raise LookupError("User not found")

    node = session.get(Node, str(payload.node_id))
    if node is None:
        raise LookupError("Node not found")

    access_key = AccessKey(
        name=payload.name,
        user_id=str(payload.user_id),
        node_id=str(payload.node_id),
        cipher=payload.cipher,
        secret=payload.secret or token_hex(16),
        is_active=payload.is_active,
    )
    session.add(access_key)
    try:
        session.commit()
    except IntegrityError as error:
        session.rollback()
        raise ValueError("Access key violates uniqueness constraints") from error
    session.refresh(access_key)
    return access_key


def deactivate_access_key(session: Session, access_key_id: UUID) -> AccessKey | None:
    access_key = get_access_key(session, access_key_id)
    if access_key is None:
        return None

    access_key.is_active = False
    session.commit()
    session.refresh(access_key)
    return access_key


def build_access_key_config(session: Session, access_key_id: UUID) -> AccessKeyConfigRead:
    access_key = get_access_key(session, access_key_id)
    if access_key is None:
        raise LookupError("Access key not found")

    node = session.get(Node, access_key.node_id)
    if node is None:
        raise LookupError("Node not found")

    user = session.get(User, access_key.user_id)
    if user is None:
        raise LookupError("User not found")

    user_info = f"{access_key.cipher}:{access_key.secret}".encode()
    encoded_credential = urlsafe_b64encode(user_info).decode("utf-8").rstrip("=")
    tag = f"{user.username}-{access_key.name}"
    ss_url = f"ss://{encoded_credential}@{node.host}:{node.port}#{quote(tag)}"

    return AccessKeyConfigRead(
        access_key_id=UUID(access_key.id),
        name=access_key.name,
        server=node.host,
        server_port=node.port,
        method=access_key.cipher,
        password=access_key.secret,
        tag=tag,
        ss_url=ss_url,
    )


def build_user_config_bundle(session: Session, user_id: UUID) -> UserConfigBundleRead:
    user = get_user(session, user_id)
    if user is None:
        raise LookupError("User not found")

    access_keys = list(
        session.scalars(
            select(AccessKey)
            .where(AccessKey.user_id == str(user_id), AccessKey.is_active.is_(True))
            .order_by(AccessKey.created_at.desc())
        )
    )

    configs: list[AccessKeyConfigRead] = []
    for access_key in access_keys:
        node = session.get(Node, access_key.node_id)
        if node is None or not node.is_active:
            continue
        configs.append(build_access_key_config(session, UUID(access_key.id)))

    return UserConfigBundleRead(
        user_id=UUID(user.id),
        username=user.username,
        configs=configs,
    )


def get_user_by_client_token(session: Session, client_token: str) -> User | None:
    return session.scalar(select(User).where(User.client_token == client_token))


def get_user_client_token(session: Session, user_id: UUID) -> UserClientTokenRead:
    user = get_user(session, user_id)
    if user is None:
        raise LookupError("User not found")

    return UserClientTokenRead(
        user_id=UUID(user.id),
        username=user.username,
        client_token=user.client_token,
    )


def rotate_user_client_token(session: Session, user_id: UUID) -> UserClientTokenRead:
    user = get_user(session, user_id)
    if user is None:
        raise LookupError("User not found")

    user.client_token = token_hex(24)
    session.commit()
    session.refresh(user)

    return UserClientTokenRead(
        user_id=UUID(user.id),
        username=user.username,
        client_token=user.client_token,
    )
