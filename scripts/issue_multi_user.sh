#!/usr/bin/env bash
set -euo pipefail

USERNAME="${1:-}"
ENV_FILE="${2:-deploy/.env.server}"
USERS_FILE="${3:-deploy/users-multi.txt}"

if [[ -z "${USERNAME}" ]]; then
  echo "Usage: $0 <username> [env_file] [users_file]" >&2
  exit 1
fi

if [[ ! "${USERNAME}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  echo "Invalid username: ${USERNAME}" >&2
  echo "Allowed: a-z A-Z 0-9 . _ -" >&2
  exit 1
fi

if [[ ! -r "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}" >&2
  exit 1
fi

source "${ENV_FILE}"

: "${SS_MULTI_DEFAULT_METHOD:?Missing SS_MULTI_DEFAULT_METHOD in ${ENV_FILE}}"
: "${SS_MULTI_PORT_MIN:?Missing SS_MULTI_PORT_MIN in ${ENV_FILE}}"
: "${SS_MULTI_PORT_MAX:?Missing SS_MULTI_PORT_MAX in ${ENV_FILE}}"

mkdir -p "$(dirname "${USERS_FILE}")"
touch "${USERS_FILE}"

if awk -F: -v target="${USERNAME}" '$1 == target {found=1} END {exit(found ? 0 : 1)}' "${USERS_FILE}"; then
  bash "$(dirname "$0")/print_multi_user_config.sh" "${USERNAME}" "${ENV_FILE}" "${USERS_FILE}"
  exit 0
fi

declare -A used_ports=()
while IFS=: read -r name port _rest; do
  [[ -z "${name}" || -z "${port}" ]] && continue
  used_ports["${port}"]=1
done <"${USERS_FILE}"

picked_port=""
for ((p = SS_MULTI_PORT_MIN; p <= SS_MULTI_PORT_MAX; p++)); do
  if [[ -n "${used_ports[$p]+x}" ]]; then
    continue
  fi
  if ss -lntu | grep -q ":${p}\\b"; then
    continue
  fi
  picked_port="${p}"
  break
done

if [[ -z "${picked_port}" ]]; then
  echo "No free ports left in range ${SS_MULTI_PORT_MIN}-${SS_MULTI_PORT_MAX}" >&2
  exit 1
fi

password="$(openssl rand -hex 16)"
printf '%s:%s:%s:%s\n' "${USERNAME}" "${picked_port}" "${password}" "${SS_MULTI_DEFAULT_METHOD}" >>"${USERS_FILE}"

bash "$(dirname "$0")/print_multi_user_config.sh" "${USERNAME}" "${ENV_FILE}" "${USERS_FILE}"
