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
