from fastapi.testclient import TestClient


def test_create_and_list_users(client: TestClient, admin_headers: dict[str, str]) -> None:
    create_response = client.post(
        "/api/v1/users",
        headers=admin_headers,
        json={
            "username": "sergei",
            "email": "sergei@example.com",
            "is_active": True,
        },
    )

    assert create_response.status_code == 201
    created = create_response.json()
    assert created["username"] == "sergei"

    list_response = client.get("/api/v1/users", headers=admin_headers)

    assert list_response.status_code == 200
    assert len(list_response.json()) == 1


def test_users_require_admin_token(client: TestClient) -> None:
    response = client.get("/api/v1/users")

    assert response.status_code == 401


def test_rotate_user_client_token(client: TestClient, admin_headers: dict[str, str]) -> None:
    create_response = client.post(
        "/api/v1/users",
        headers=admin_headers,
        json={
            "username": "rotate-me",
            "email": "rotate-me@example.com",
            "is_active": True,
        },
    )
    user_id = create_response.json()["id"]

    token_response = client.get(
        f"/api/v1/users/{user_id}/client-token",
        headers=admin_headers,
    )
    original_token = token_response.json()["client_token"]

    rotate_response = client.post(
        f"/api/v1/users/{user_id}/client-token/rotate",
        headers=admin_headers,
    )

    assert rotate_response.status_code == 200
    rotated_token = rotate_response.json()["client_token"]
    assert rotated_token != original_token
