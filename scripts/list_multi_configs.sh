#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-deploy/.env.server}"
USERS_FILE="${2:-deploy/users-multi.txt}"

if [[ ! -f "${USERS_FILE}" ]]; then
  exit 0
fi

while IFS=: read -r username _rest; do
  [[ -z "${username}" ]] && continue
  bash "$(dirname "$0")/print_multi_user_config.sh" "${username}" "${ENV_FILE}" "${USERS_FILE}"
done <"${USERS_FILE}"
