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

source deploy/.env.server

: "${SSSERVER_PUBLIC_HOST:?Missing SSSERVER_PUBLIC_HOST in deploy/.env.server}"
: "${SSSERVER_PORT:?Missing SSSERVER_PORT in deploy/.env.server}"
: "${SSSERVER_METHOD:?Missing SSSERVER_METHOD in deploy/.env.server}"
: "${SSSERVER_PASSWORD:?Missing SSSERVER_PASSWORD in deploy/.env.server}"

SSSERVER_MODE="${SSSERVER_MODE:-tcp_and_udp}"
SSSERVER_TIMEOUT="${SSSERVER_TIMEOUT:-60}"

cat >deploy/ssserver.json <<EOF
{
  "server": "0.0.0.0",
  "server_port": ${SSSERVER_PORT},
  "mode": "${SSSERVER_MODE}",
  "password": "${SSSERVER_PASSWORD}",
  "method": "${SSSERVER_METHOD}",
  "timeout": ${SSSERVER_TIMEOUT}
}
EOF

chmod 600 deploy/ssserver.json

if command -v ufw >/dev/null 2>&1; then
  if ufw status | grep -q '^Status: active'; then
    ufw allow "${SSSERVER_PORT}/tcp" >/dev/null
    ufw allow "${SSSERVER_PORT}/udp" >/dev/null
  fi
fi

compose_args=(
  --env-file deploy/.env.server
  -f deploy/docker-compose.server.yml
)

docker compose "${compose_args[@]}" up -d --pull always --remove-orphans
docker compose "${compose_args[@]}" ps

for attempt in {1..20}; do
  if [[ "$(docker inspect -f '{{.State.Running}}' opensocks-ssserver 2>/dev/null || true)" == "true" ]]; then
    break
  fi
  sleep 2
done

if [[ "$(docker inspect -f '{{.State.Running}}' opensocks-ssserver 2>/dev/null || true)" != "true" ]]; then
  echo "Shadowsocks server failed to start."
  docker compose "${compose_args[@]}" logs ssserver
  exit 1
fi

if ! ss -lnt | grep -q ":${SSSERVER_PORT}\\b"; then
  echo "TCP port ${SSSERVER_PORT} is not listening on the host."
  docker compose "${compose_args[@]}" logs ssserver
  exit 1
fi

if ! ss -lnu | grep -q ":${SSSERVER_PORT}\\b"; then
  echo "UDP port ${SSSERVER_PORT} is not listening on the host."
  docker compose "${compose_args[@]}" logs ssserver
  exit 1
fi

echo "Shadowsocks is up on ${SSSERVER_PUBLIC_HOST}:${SSSERVER_PORT} (${SSSERVER_MODE})."
