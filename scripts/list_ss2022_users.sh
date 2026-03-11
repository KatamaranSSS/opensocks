#!/usr/bin/env bash
set -euo pipefail

USERS_FILE="${1:-deploy/users-ss2022.txt}"

if [[ ! -f "${USERS_FILE}" ]]; then
  exit 0
fi

awk -F: 'NF >= 2 && $1 != "" {print $1}' "${USERS_FILE}" | sort -u
