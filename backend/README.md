# Backend

FastAPI-based control plane for the OpenSocks project.

## Planned responsibilities

- health and diagnostics
- node registry
- user and access management
- configuration delivery for clients
- admin authentication later

## Current API surface

- `GET /api/v1/health`
- `GET /api/v1/users`
- `POST /api/v1/users`
- `GET /api/v1/users/{user_id}`
- `GET /api/v1/nodes`
- `POST /api/v1/nodes`
- `GET /api/v1/nodes/{node_id}`

All `users` and `nodes` endpoints require:

- `Authorization: Bearer <ADMIN_API_TOKEN>`

## Local development

Expected command after dependencies are installed:

```bash
pip install -e ".[dev]"
pytest
uvicorn app.main:app --reload
```
