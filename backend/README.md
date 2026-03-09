# Backend

FastAPI-based control plane for the OpenSocks project.

## Planned responsibilities

- health and diagnostics
- node registry
- user and access management
- configuration delivery for clients
- admin authentication later

## Local development

Expected command after dependencies are installed:

```bash
pip install -e ".[dev]"
pytest
uvicorn app.main:app --reload
```

