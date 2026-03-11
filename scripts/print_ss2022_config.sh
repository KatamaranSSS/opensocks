#!/usr/bin/env bash
set -euo pipefail

USERNAME="${1:-}"
ENV_FILE="${2:-deploy/.env.server}"
USERS_FILE="${3:-deploy/users-ss2022.txt}"

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

if [[ ! -r "${USERS_FILE}" ]]; then
  echo "Missing SS2022 users file: ${USERS_FILE}" >&2
  exit 1
fi

source "${ENV_FILE}"

: "${SS2022_PUBLIC_HOST:?Missing SS2022_PUBLIC_HOST in ${ENV_FILE}}"
: "${SS2022_PORT:?Missing SS2022_PORT in ${ENV_FILE}}"
: "${SS2022_METHOD:?Missing SS2022_METHOD in ${ENV_FILE}}"
: "${SS2022_PASSWORD_BASE64:?Missing SS2022_PASSWORD_BASE64 in ${ENV_FILE}}"

user_psk="$(awk -F: -v target="${USERNAME}" '$1 == target {print $2; exit}' "${USERS_FILE}")"

if [[ -z "${user_psk}" ]]; then
  echo "SS2022 user not found: ${USERNAME}" >&2
  exit 1
fi

if [[ ! "${user_psk}" =~ ^[A-Za-z0-9+/=]+$ ]]; then
  echo "Invalid SS2022 user key for ${USERNAME}" >&2
  exit 1
fi

# For SS2022-EIH client password format is iPSK:uPSK.
combined_password="${SS2022_PASSWORD_BASE64}:${user_psk}"

urlencode() {
  local raw="${1}"
  raw="${raw//%/%25}"
  raw="${raw//#/%23}"
  raw="${raw//:/%3A}"
  raw="${raw//\//%2F}"
  raw="${raw//+/%2B}"
  raw="${raw//=/%3D}"
  printf '%s' "${raw}"
}

encoded_password="$(urlencode "${combined_password}")"
printf 'ss://%s:%s@%s:%s#%s\n' \
  "${SS2022_METHOD}" \
  "${encoded_password}" \
  "${SS2022_PUBLIC_HOST}" \
  "${SS2022_PORT}" \
  "${USERNAME}"
