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

if [[ -f "opensocks-api.tar" ]]; then
  docker load -i opensocks-api.tar
  rm -f opensocks-api.tar
fi

docker compose --env-file deploy/.env.server -f deploy/docker-compose.server.yml up -d
docker compose --env-file deploy/.env.server -f deploy/docker-compose.server.yml ps

for attempt in {1..20}; do
  if curl --fail --silent http://127.0.0.1:18000/api/v1/health >/dev/null; then
    echo "Health check passed on http://127.0.0.1:18000/api/v1/health"
    exit 0
  fi
  sleep 2
done

echo "Health check failed after waiting for API readiness."
docker compose --env-file deploy/.env.server -f deploy/docker-compose.server.yml logs api
exit 1
