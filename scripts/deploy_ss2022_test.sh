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
SS2022_USERS_FILE="${SS2022_USERS_FILE:-deploy/users-ss2022.txt}"

mkdir -p "$(dirname "${SS2022_USERS_FILE}")"
touch "${SS2022_USERS_FILE}"

users_json=""
users_count=0

while IFS= read -r raw_line || [[ -n "${raw_line}" ]]; do
  line="${raw_line%$'\r'}"
  line="$(printf '%s' "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -z "${line}" ]] && continue
  [[ "${line}" =~ ^# ]] && continue

  name="${line%%:*}"
  password="${line#*:}"

  if [[ "${line}" == "${name}" ]]; then
    echo "Invalid SS2022 users line (expected username:password): ${line}" >&2
    exit 1
  fi

  if [[ ! "${name}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Invalid SS2022 username: ${name}" >&2
    exit 1
  fi

  if [[ ! "${password}" =~ ^[A-Za-z0-9+/=]+$ ]]; then
    echo "Invalid SS2022 password for user ${name}" >&2
    exit 1
  fi

  if [[ -n "${users_json}" ]]; then
    users_json+=$',\n'
  fi
  users_json+="    {\"name\": \"${name}\", \"password\": \"${password}\"}"
  users_count=$((users_count + 1))
done <"${SS2022_USERS_FILE}"

cat >deploy/ssserver-2022.json <<EOF
{
  "server": "0.0.0.0",
  "server_port": ${SS2022_PORT},
  "mode": "${SS2022_MODE}",
  "method": "${SS2022_METHOD}",
  "password": "${SS2022_PASSWORD_BASE64}",
  "users": [
${users_json}
  ],
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
docker compose "${compose_args[@]}" up -d --pull always --force-recreate ssserver2022
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

echo "SS2022 test server is up on ${SS2022_PUBLIC_HOST}:${SS2022_PORT} (${SS2022_MODE}), users=${users_count}."
