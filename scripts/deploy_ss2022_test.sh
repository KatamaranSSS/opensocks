#!/usr/bin/env bash
set -euo pipefail

DEPLOY_PATH="${DEPLOY_PATH:-/opt/opensocks}"
ENV_FILE="${ENV_FILE:-deploy/.env.server}"

if [[ ! -d "${DEPLOY_PATH}" ]]; then
  echo "Deploy path ${DEPLOY_PATH} does not exist." >&2
  exit 1
fi

cd "${DEPLOY_PATH}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}" >&2
  exit 1
fi

source "${ENV_FILE}"

: "${SS2022_PUBLIC_HOST:?Missing SS2022_PUBLIC_HOST in ${ENV_FILE}}"
: "${SS2022_PORT:?Missing SS2022_PORT in ${ENV_FILE}}"
: "${SS2022_METHOD:?Missing SS2022_METHOD in ${ENV_FILE}}"
: "${SS2022_PASSWORD_BASE64:?Missing SS2022_PASSWORD_BASE64 in ${ENV_FILE}}"

SS2022_MODE="${SS2022_MODE:-tcp_and_udp}"
SS2022_TIMEOUT="${SS2022_TIMEOUT:-60}"
SS2022_IMAGE="${SS2022_IMAGE:-ghcr.io/shadowsocks/ssserver-rust:latest}"
SS2022_COMMAND="${SS2022_COMMAND:-ssserver -c /etc/shadowsocks/config.json}"

cat >deploy/ssserver-2022.json <<EOF
{
  "server": "0.0.0.0",
  "server_port": ${SS2022_PORT},
  "mode": "${SS2022_MODE}",
  "method": "${SS2022_METHOD}",
  "password": "${SS2022_PASSWORD_BASE64}",
  "timeout": ${SS2022_TIMEOUT}
}
EOF

chmod 600 deploy/ssserver-2022.json
export SS2022_IMAGE SS2022_COMMAND

if command -v ufw >/dev/null 2>&1; then
  if ufw status | grep -q '^Status: active'; then
    ufw allow "${SS2022_PORT}/tcp" >/dev/null
    ufw allow "${SS2022_PORT}/udp" >/dev/null
  fi
fi

compose_args=(
  --env-file "${ENV_FILE}"
  -f deploy/docker-compose.ss2022-test.yml
)

# Do not use --remove-orphans here to avoid touching the main production stack.
docker compose "${compose_args[@]}" up -d --pull always
docker compose "${compose_args[@]}" ps

for attempt in {1..20}; do
  if [[ "$(docker inspect -f '{{.State.Running}}' opensocks-ssserver-2022 2>/dev/null || true)" == "true" ]]; then
    break
  fi
  sleep 2
done

if [[ "$(docker inspect -f '{{.State.Running}}' opensocks-ssserver-2022 2>/dev/null || true)" != "true" ]]; then
  echo "Shadowsocks SS2022 test server failed to start." >&2
  docker compose "${compose_args[@]}" logs ssserver2022
  exit 1
fi

if ! ss -lnt | grep -q ":${SS2022_PORT}\\b"; then
  echo "TCP port ${SS2022_PORT} is not listening on the host." >&2
  docker compose "${compose_args[@]}" logs ssserver2022
  exit 1
fi

if [[ "${SS2022_MODE}" == *"udp"* ]] && ! ss -lnu | grep -q ":${SS2022_PORT}\\b"; then
  echo "UDP port ${SS2022_PORT} is not listening on the host." >&2
  docker compose "${compose_args[@]}" logs ssserver2022
  exit 1
fi

echo "SS2022 test server is up on ${SS2022_PUBLIC_HOST}:${SS2022_PORT} (${SS2022_MODE})."
