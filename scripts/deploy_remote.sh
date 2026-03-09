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

source deploy/.env.server

compose_args=(
  --env-file deploy/.env.server
  -f deploy/docker-compose.server.yml
)

if [[ "${SSSERVER_ENABLED:-false}" == "true" ]]; then
  compose_args+=(-f deploy/docker-compose.shadowsocks.yml)
fi

docker compose "${compose_args[@]}" up -d
docker compose "${compose_args[@]}" ps

if [[ "${SSSERVER_ENABLED:-false}" == "true" ]]; then
  for attempt in {1..20}; do
    if [[ "$(docker inspect -f '{{.State.Running}}' opensocks-ssserver 2>/dev/null || true)" == "true" ]]; then
      echo "Shadowsocks server is running on tcp/${SSSERVER_PORT}"
      break
    fi
    sleep 2
  done

  if [[ "$(docker inspect -f '{{.State.Running}}' opensocks-ssserver 2>/dev/null || true)" != "true" ]]; then
    echo "Shadowsocks server failed to start."
    docker compose "${compose_args[@]}" logs ssserver
    exit 1
  fi
fi

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
