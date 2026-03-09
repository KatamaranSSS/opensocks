#!/usr/bin/env bash
set -euo pipefail

DEPLOY_PATH="${DEPLOY_PATH:-/opt/opensocks}"

if [[ ! -d "${DEPLOY_PATH}" ]]; then
  echo "Deploy path ${DEPLOY_PATH} does not exist."
  exit 1
fi

cd "${DEPLOY_PATH}"

if [[ ! -f "deploy/.env.server" ]]; then
  echo "Missing deploy/.env.server"
  exit 1
fi

docker compose --env-file deploy/.env.server -f deploy/docker-compose.server.yml up --build -d
docker compose --env-file deploy/.env.server -f deploy/docker-compose.server.yml ps
curl --fail --silent http://127.0.0.1:18000/api/v1/health >/dev/null
echo "Health check passed on http://127.0.0.1:18000/api/v1/health"
