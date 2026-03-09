from fastapi.testclient import TestClient


def test_get_user_configs_returns_only_active_keys(
    client: TestClient,
    admin_headers: dict[str, str],
) -> None:
    user_response = client.post(
        "/api/v1/users",
        headers=admin_headers,
        json={
            "username": "bundle-user",
            "email": "bundle-user@example.com",
            "is_active": True,
        },
    )
    node_response = client.post(
        "/api/v1/nodes",
        headers=admin_headers,
        json={
            "name": "bundle-node",
            "host": "109.71.246.216",
            "port": 8396,
            "country_code": "RU",
            "is_active": True,
        },
    )

    user_id = user_response.json()["id"]
    node_id = node_response.json()["id"]

    active_key_response = client.post(
        "/api/v1/access-keys",
        headers=admin_headers,
        json={
            "name": "bundle-active-key",
            "user_id": user_id,
            "node_id": node_id,
            "cipher": "chacha20-ietf-poly1305",
            "is_active": True,
        },
    )
    inactive_key_response = client.post(
        "/api/v1/access-keys",
        headers=admin_headers,
        json={
            "name": "bundle-inactive-key",
            "user_id": user_id,
            "node_id": node_id,
            "cipher": "chacha20-ietf-poly1305",
            "is_active": False,
        },
    )

    assert active_key_response.status_code == 201
    assert inactive_key_response.status_code == 201

    bundle_response = client.get(
        f"/api/v1/users/{user_id}/configs",
        headers=admin_headers,
    )

    assert bundle_response.status_code == 200
    payload = bundle_response.json()
    assert payload["username"] == "bundle-user"
    assert len(payload["configs"]) == 1
    assert payload["configs"][0]["name"] == "bundle-active-key"
    assert payload["configs"][0]["ss_url"].startswith("ss://")
