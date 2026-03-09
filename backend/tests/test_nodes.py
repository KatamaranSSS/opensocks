from fastapi.testclient import TestClient


def test_create_and_list_nodes(client: TestClient) -> None:
    create_response = client.post(
        "/api/v1/nodes",
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

    list_response = client.get("/api/v1/nodes")

    assert list_response.status_code == 200
    assert len(list_response.json()) == 1
