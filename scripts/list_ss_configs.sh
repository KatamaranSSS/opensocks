#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-deploy/.env.server}"
USERS_FILE="${2:-deploy/users.txt}"

if [[ ! -f "${USERS_FILE}" ]]; then
  exit 0
fi

while IFS= read -r username; do
  [[ -z "${username}" ]] && continue
  bash "$(dirname "$0")/print_ss_config.sh" "${username}" "${ENV_FILE}"
done < <(grep -v '^[[:space:]]*$' "${USERS_FILE}" | sort -u)
