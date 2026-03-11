#!/usr/bin/env bash
set -euo pipefail

USERNAME="${1:-}"
USERS_FILE="${2:-deploy/users-ss2022.txt}"

if [[ -z "${USERNAME}" ]]; then
  echo "Usage: $0 <username> [users_file]" >&2
  exit 1
fi

if [[ ! "${USERNAME}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  echo "Invalid username: ${USERNAME}" >&2
  echo "Allowed: a-z A-Z 0-9 . _ -" >&2
  exit 1
fi

if [[ ! -f "${USERS_FILE}" ]]; then
  echo "Users file not found: ${USERS_FILE}" >&2
  exit 1
fi

tmp="$(mktemp)"
found=0

while IFS= read -r line || [[ -n "${line}" ]]; do
  name="${line%%:*}"
  if [[ "${name}" == "${USERNAME}" ]]; then
    found=1
    continue
  fi
  printf '%s\n' "${line}" >>"${tmp}"
done <"${USERS_FILE}"

if [[ "${found}" -eq 0 ]]; then
  rm -f "${tmp}"
  echo "Username not found: ${USERNAME}" >&2
  exit 1
fi

mv "${tmp}" "${USERS_FILE}"
echo "Removed SS2022 user: ${USERNAME}"
