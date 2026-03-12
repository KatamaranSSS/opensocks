#!/usr/bin/env bash
set -euo pipefail

USERS_FILE="${1:-deploy/users-multi.txt}"

if [[ ! -f "${USERS_FILE}" ]]; then
  exit 0
fi

awk -F: 'NF >= 4 {printf "%s\t%s\t%s\n", $1, $2, $4}' "${USERS_FILE}" | sort -u
