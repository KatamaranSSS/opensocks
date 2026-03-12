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

if [[ ! -r "${USERS_FILE}" ]]; then
  echo "Missing users file: ${USERS_FILE}" >&2
  exit 1
fi

source "${ENV_FILE}"

: "${SS_MULTI_PUBLIC_HOST:?Missing SS_MULTI_PUBLIC_HOST in ${ENV_FILE}}"
: "${SS_MULTI_DEFAULT_METHOD:?Missing SS_MULTI_DEFAULT_METHOD in ${ENV_FILE}}"

entry="$(awk -F: -v target="${USERNAME}" '$1 == target {print; exit}' "${USERS_FILE}")"

if [[ -z "${entry}" ]]; then
  echo "User not found: ${USERNAME}" >&2
  exit 1
fi

IFS=':' read -r login port password method <<<"${entry}"

if [[ -z "${method}" ]]; then
  method="${SS_MULTI_DEFAULT_METHOD}"
fi

encoded="$(printf '%s' "${method}:${password}" | base64 | tr -d '\n=')"
printf 'ss://%s@%s:%s#%s\n' "${encoded}" "${SS_MULTI_PUBLIC_HOST}" "${port}" "${login}"
