#!/usr/bin/env bash
set -euo pipefail

USERS_FILE="${1:-deploy/users.txt}"

if [[ ! -f "${USERS_FILE}" ]]; then
  exit 0
fi

grep -v '^[[:space:]]*$' "${USERS_FILE}" | sort -u
