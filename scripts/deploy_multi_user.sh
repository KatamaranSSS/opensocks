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

: "${SS_MULTI_PUBLIC_HOST:?Missing SS_MULTI_PUBLIC_HOST in ${ENV_FILE}}"
: "${SS_MULTI_DEFAULT_METHOD:?Missing SS_MULTI_DEFAULT_METHOD in ${ENV_FILE}}"

SS_MULTI_MODE="${SS_MULTI_MODE:-tcp_and_udp}"
SS_MULTI_TIMEOUT="${SS_MULTI_TIMEOUT:-60}"
SS_MULTI_IMAGE="${SS_MULTI_IMAGE:-ghcr.io/shadowsocks/ssserver-rust:latest}"
SS_MULTI_COMMAND="${SS_MULTI_COMMAND:-ssserver -c /etc/shadowsocks/config.json}"
SS_MULTI_USERS_FILE="${SS_MULTI_USERS_FILE:-deploy/users-multi.txt}"
SS_MULTI_WAIT_SECONDS="${SS_MULTI_WAIT_SECONDS:-20}"

wait_for_port() {
  local protocol="$1"
  local port="$2"
  local elapsed=0
  local ss_args="-lnt"

  if [[ "${protocol}" == "udp" ]]; then
    ss_args="-lnu"
  fi

  while (( elapsed < SS_MULTI_WAIT_SECONDS )); do
    if ss ${ss_args} | grep -q ":${port}\\b"; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  return 1
}

mkdir -p "$(dirname "${SS_MULTI_USERS_FILE}")"
touch "${SS_MULTI_USERS_FILE}"

servers_json=""
port_list=()
users_count=0

while IFS= read -r raw_line || [[ -n "${raw_line}" ]]; do
  line="${raw_line%$'\r'}"
  line="$(printf '%s' "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -z "${line}" ]] && continue
  [[ "${line}" =~ ^# ]] && continue

  IFS=':' read -r username port password method <<<"${line}"

  if [[ -z "${username}" || -z "${port}" || -z "${password}" ]]; then
    echo "Invalid users line (expected username:port:password[:method]): ${line}" >&2
    exit 1
  fi

  if [[ -z "${method}" ]]; then
    method="${SS_MULTI_DEFAULT_METHOD}"
  fi

  if [[ ! "${username}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Invalid username in users file: ${username}" >&2
    exit 1
  fi

  if [[ ! "${port}" =~ ^[0-9]+$ ]]; then
    echo "Invalid port for ${username}: ${port}" >&2
    exit 1
  fi

  if ((port < 1 || port > 65535)); then
    echo "Port out of range for ${username}: ${port}" >&2
    exit 1
  fi

  if [[ ! "${method}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Invalid method for ${username}: ${method}" >&2
    exit 1
  fi

  if [[ -n "${servers_json}" ]]; then
    servers_json+=$',\n'
  fi
  servers_json+="    {\"server\": \"0.0.0.0\", \"server_port\": ${port}, \"password\": \"${password}\", \"method\": \"${method}\"}"
  port_list+=("${port}")
  users_count=$((users_count + 1))
done <"${SS_MULTI_USERS_FILE}"

if [[ "${users_count}" -eq 0 ]]; then
  echo "No users in ${SS_MULTI_USERS_FILE}. Create users first with scripts/issue_multi_user.sh" >&2
  exit 1
fi

cat >deploy/ssserver-multi.json <<EOF
{
  "mode": "${SS_MULTI_MODE}",
  "timeout": ${SS_MULTI_TIMEOUT},
  "servers": [
${servers_json}
  ]
}
EOF

chmod 600 deploy/ssserver-multi.json
export SS_MULTI_IMAGE SS_MULTI_COMMAND

if command -v ufw >/dev/null 2>&1; then
  if ufw status | grep -q '^Status: active'; then
    for port in "${port_list[@]}"; do
      ufw allow "${port}/tcp" >/dev/null
      ufw allow "${port}/udp" >/dev/null
    done
  fi
fi

compose_args=(
  --env-file "${ENV_FILE}"
  -f deploy/docker-compose.multi-user.yml
)

# Do not use --remove-orphans here to avoid touching other stacks.
COMPOSE_IGNORE_ORPHANS=True docker compose "${compose_args[@]}" up -d --pull missing --force-recreate ssserver-multi

if [[ "$(docker inspect -f '{{.State.Running}}' opensocks-ssserver-multi 2>/dev/null || true)" != "true" ]]; then
  echo "Shadowsocks multi-user server failed to start." >&2
  docker compose "${compose_args[@]}" logs ssserver-multi
  exit 1
fi

for port in "${port_list[@]}"; do
  if ! wait_for_port tcp "${port}"; then
    echo "TCP port ${port} is not listening." >&2
    docker compose "${compose_args[@]}" logs ssserver-multi
    exit 1
  fi
  if [[ "${SS_MULTI_MODE}" == *"udp"* ]] && ! wait_for_port udp "${port}"; then
    echo "UDP port ${port} is not listening." >&2
    docker compose "${compose_args[@]}" logs ssserver-multi
    exit 1
  fi
done

echo "Multi-user Shadowsocks is up for ${users_count} users on ${SS_MULTI_PUBLIC_HOST}."
