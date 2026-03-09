from fastapi.testclient import TestClient


def test_create_and_list_nodes(client: TestClient, admin_headers: dict[str, str]) -> None:
    create_response = client.post(
        "/api/v1/nodes",
        headers=admin_headers,
        json={
            "name": "moscow-test-node",
            "host": "109.71.246.216",
            "port": 8388,
            "country_code": "RU",
            "is_active": True,
        },
    )

    assert create_response.status_code == 201
    created = create_response.json()
    assert created["name"] == "moscow-test-node"

    list_response = client.get("/api/v1/nodes", headers=admin_headers)

    assert list_response.status_code == 200
    assert len(list_response.json()) == 1


def test_nodes_require_admin_token(client: TestClient) -> None:
    response = client.get("/api/v1/nodes")

    assert response.status_code == 401


def test_nodes_allow_same_host_on_different_ports(
    client: TestClient,
    admin_headers: dict[str, str],
) -> None:
    first_response = client.post(
        "/api/v1/nodes",
        headers=admin_headers,
        json={
            "name": "msk-node-1",
            "host": "109.71.246.216",
            "port": 8388,
            "country_code": "RU",
            "is_active": True,
        },
    )
    second_response = client.post(
        "/api/v1/nodes",
        headers=admin_headers,
        json={
            "name": "msk-node-2",
            "host": "109.71.246.216",
            "port": 8389,
            "country_code": "RU",
            "is_active": True,
        },
    )

    assert first_response.status_code == 201
    assert second_response.status_code == 201


def test_nodes_reject_duplicate_host_port(
    client: TestClient,
    admin_headers: dict[str, str],
) -> None:
    first_response = client.post(
        "/api/v1/nodes",
        headers=admin_headers,
        json={
            "name": "dup-node-1",
            "host": "109.71.246.216",
            "port": 8390,
            "country_code": "RU",
            "is_active": True,
        },
    )
    second_response = client.post(
        "/api/v1/nodes",
        headers=admin_headers,
        json={
            "name": "dup-node-2",
            "host": "109.71.246.216",
            "port": 8390,
            "country_code": "RU",
            "is_active": True,
        },
    )

    assert first_response.status_code == 201
    assert second_response.status_code == 409
