#!/usr/bin/env bash
set -euo pipefail

USERNAME="${1:-}"
ENV_FILE="${2:-deploy/.env.server}"
USERS_FILE="${3:-deploy/users.txt}"

if [[ -z "${USERNAME}" ]]; then
  echo "Usage: $0 <username> [env_file] [users_file]" >&2
  exit 1
fi

if [[ ! "${USERNAME}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  echo "Invalid username: ${USERNAME}" >&2
  echo "Allowed: a-z A-Z 0-9 . _ -" >&2
  exit 1
fi

mkdir -p "$(dirname "${USERS_FILE}")"
touch "${USERS_FILE}"

if ! grep -qx "${USERNAME}" "${USERS_FILE}"; then
  printf '%s\n' "${USERNAME}" >>"${USERS_FILE}"
fi

bash "$(dirname "$0")/print_ss_config.sh" "${USERNAME}" "${ENV_FILE}"
