from fastapi.testclient import TestClient


def test_client_bootstrap_works_with_client_token(
    client: TestClient,
    admin_headers: dict[str, str],
) -> None:
    user_response = client.post(
        "/api/v1/users",
        headers=admin_headers,
        json={
            "username": "client-user",
            "email": "client-user@example.com",
            "is_active": True,
        },
    )
    user_id = user_response.json()["id"]

    token_response = client.get(
        f"/api/v1/users/{user_id}/client-token",
        headers=admin_headers,
    )
    client_token = token_response.json()["client_token"]

    node_response = client.post(
        "/api/v1/nodes",
        headers=admin_headers,
        json={
            "name": "client-node",
            "host": "109.71.246.216",
            "port": 8397,
            "country_code": "RU",
            "is_active": True,
        },
    )
    node_id = node_response.json()["id"]

    create_access_key_response = client.post(
        "/api/v1/access-keys",
        headers=admin_headers,
        json={
            "name": "client-access-key",
            "user_id": user_id,
            "node_id": node_id,
            "cipher": "chacha20-ietf-poly1305",
            "is_active": True,
        },
    )

    assert create_access_key_response.status_code == 201

    bootstrap_response = client.get(
        "/api/v1/client/bootstrap",
        headers={"Authorization": f"Bearer {client_token}"},
    )

    assert bootstrap_response.status_code == 200
    payload = bootstrap_response.json()
    assert payload["username"] == "client-user"
    assert len(payload["configs"]) == 1


def test_client_bootstrap_rejects_invalid_token(client: TestClient) -> None:
    response = client.get(
        "/api/v1/client/bootstrap",
        headers={"Authorization": "Bearer invalid-token"},
    )

    assert response.status_code == 401
