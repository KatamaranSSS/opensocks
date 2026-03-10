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

SSSERVER_OBFS_ENABLED="${SSSERVER_OBFS_ENABLED:-false}"
SSSERVER_MODE="${SSSERVER_MODE:-tcp_and_udp}"
SSSERVER_TIMEOUT="${SSSERVER_TIMEOUT:-60}"
SSSERVER_PLUGIN="${SSSERVER_PLUGIN:-v2ray-plugin}"

if [[ "${SSSERVER_OBFS_ENABLED}" == "true" ]]; then
  SSSERVER_IMAGE="${SSSERVER_IMAGE:-teddysun/shadowsocks-libev:latest}"
  SSSERVER_COMMAND="${SSSERVER_COMMAND:-ss-server -c /etc/shadowsocks/config.json -v}"
  SSSERVER_MODE="tcp_only"
  SSSERVER_OBFS_MODE="${SSSERVER_OBFS_MODE:-websocket}"
  SSSERVER_OBFS_PATH="${SSSERVER_OBFS_PATH:-/ws}"
  SSSERVER_OBFS_HOST="${SSSERVER_OBFS_HOST:-}"
  if [[ -n "${SSSERVER_OBFS_HOST}" ]]; then
    SSSERVER_PLUGIN_OPTS="${SSSERVER_PLUGIN_OPTS:-server;mode=${SSSERVER_OBFS_MODE};path=${SSSERVER_OBFS_PATH};host=${SSSERVER_OBFS_HOST}}"
  else
    SSSERVER_PLUGIN_OPTS="${SSSERVER_PLUGIN_OPTS:-server;mode=${SSSERVER_OBFS_MODE};path=${SSSERVER_OBFS_PATH}}"
  fi

  cat >deploy/ssserver.json <<EOF
{
  "server": "0.0.0.0",
  "server_port": ${SSSERVER_PORT},
  "mode": "${SSSERVER_MODE}",
  "password": "${SSSERVER_PASSWORD}",
  "method": "${SSSERVER_METHOD}",
  "timeout": ${SSSERVER_TIMEOUT},
  "plugin": "${SSSERVER_PLUGIN}",
  "plugin_opts": "${SSSERVER_PLUGIN_OPTS}"
}
EOF
else
  SSSERVER_IMAGE="${SSSERVER_IMAGE:-ghcr.io/shadowsocks/ssserver-rust:latest}"
  SSSERVER_COMMAND="${SSSERVER_COMMAND:-ssserver -c /etc/shadowsocks/config.json}"

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
fi

chmod 600 deploy/ssserver.json
export SSSERVER_IMAGE SSSERVER_COMMAND

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

if [[ "${SSSERVER_MODE}" == *"udp"* ]] && ! ss -lnu | grep -q ":${SSSERVER_PORT}\\b"; then
  echo "UDP port ${SSSERVER_PORT} is not listening on the host."
  docker compose "${compose_args[@]}" logs ssserver
  exit 1
fi

if [[ "${SSSERVER_OBFS_ENABLED}" == "true" ]]; then
  echo "Shadowsocks is up on ${SSSERVER_PUBLIC_HOST}:${SSSERVER_PORT} with obfuscation (${SSSERVER_PLUGIN})."
else
  echo "Shadowsocks is up on ${SSSERVER_PUBLIC_HOST}:${SSSERVER_PORT} (${SSSERVER_MODE})."
fi
