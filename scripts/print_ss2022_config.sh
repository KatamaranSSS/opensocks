#!/usr/bin/env bash
set -euo pipefail

CONFIG_NAME="${1:-opensocks-ss2022}"
ENV_FILE="${2:-deploy/.env.server}"

if [[ ! -r "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}" >&2
  exit 1
fi

source "${ENV_FILE}"

: "${SS2022_PUBLIC_HOST:?Missing SS2022_PUBLIC_HOST in ${ENV_FILE}}"
: "${SS2022_PORT:?Missing SS2022_PORT in ${ENV_FILE}}"
: "${SS2022_METHOD:?Missing SS2022_METHOD in ${ENV_FILE}}"
: "${SS2022_PASSWORD_BASE64:?Missing SS2022_PASSWORD_BASE64 in ${ENV_FILE}}"

encoded="$(printf '%s' "${SS2022_METHOD}:${SS2022_PASSWORD_BASE64}" | base64 | tr -d '\n=')"
printf 'ss://%s@%s:%s#%s\n' "${encoded}" "${SS2022_PUBLIC_HOST}" "${SS2022_PORT}" "${CONFIG_NAME}"
