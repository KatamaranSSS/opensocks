from fastapi.testclient import TestClient


def create_user_and_node(client: TestClient, admin_headers: dict[str, str]) -> tuple[str, str]:
    user_response = client.post(
        "/api/v1/users",
        headers=admin_headers,
        json={
            "username": "access-user",
            "email": "access-user@example.com",
            "is_active": True,
        },
    )
    node_response = client.post(
        "/api/v1/nodes",
        headers=admin_headers,
        json={
            "name": "access-node",
            "host": "109.71.246.216",
            "port": 8395,
            "country_code": "RU",
            "is_active": True,
        },
    )

    return user_response.json()["id"], node_response.json()["id"]


def test_create_and_list_access_keys(client: TestClient, admin_headers: dict[str, str]) -> None:
    user_id, node_id = create_user_and_node(client, admin_headers)

    create_response = client.post(
        "/api/v1/access-keys",
        headers=admin_headers,
        json={
            "name": "sergei-main-key",
            "user_id": user_id,
            "node_id": node_id,
            "cipher": "chacha20-ietf-poly1305",
            "is_active": True,
        },
    )

    assert create_response.status_code == 201
    created = create_response.json()
    assert created["name"] == "sergei-main-key"
    assert created["secret"]

    list_response = client.get("/api/v1/access-keys", headers=admin_headers)

    assert list_response.status_code == 200
    assert len(list_response.json()) == 1


def test_access_keys_require_admin_token(client: TestClient) -> None:
    response = client.get("/api/v1/access-keys")

    assert response.status_code == 401


def test_access_key_config_contains_ss_url(
    client: TestClient,
    admin_headers: dict[str, str],
) -> None:
    user_id, node_id = create_user_and_node(client, admin_headers)
    access_key_response = client.post(
        "/api/v1/access-keys",
        headers=admin_headers,
        json={
            "name": "config-key",
            "user_id": user_id,
            "node_id": node_id,
            "cipher": "chacha20-ietf-poly1305",
            "secret": "testsecret123",
            "is_active": True,
        },
    )
    access_key_id = access_key_response.json()["id"]

    config_response = client.get(
        f"/api/v1/access-keys/{access_key_id}/config",
        headers=admin_headers,
    )

    assert config_response.status_code == 200
    config = config_response.json()
    assert config["server"] == "109.71.246.216"
    assert config["server_port"] == 8395
    assert config["ss_url"].startswith("ss://")


def test_deactivate_access_key(client: TestClient, admin_headers: dict[str, str]) -> None:
    user_id, node_id = create_user_and_node(client, admin_headers)
    create_response = client.post(
        "/api/v1/access-keys",
        headers=admin_headers,
        json={
            "name": "deactivate-key",
            "user_id": user_id,
            "node_id": node_id,
            "cipher": "chacha20-ietf-poly1305",
            "is_active": True,
        },
    )
    access_key_id = create_response.json()["id"]

    deactivate_response = client.post(
        f"/api/v1/access-keys/{access_key_id}/deactivate",
        headers=admin_headers,
    )

    assert deactivate_response.status_code == 200
    assert deactivate_response.json()["is_active"] is False
