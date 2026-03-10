#!/usr/bin/env bash
set -euo pipefail

CONFIG_NAME="${1:-opensocks}"
ENV_FILE="${2:-deploy/.env.server}"

if [[ ! -r "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}" >&2
  exit 1
fi

source "${ENV_FILE}"

: "${SSSERVER_PUBLIC_HOST:?Missing SSSERVER_PUBLIC_HOST in ${ENV_FILE}}"
: "${SSSERVER_PORT:?Missing SSSERVER_PORT in ${ENV_FILE}}"
: "${SSSERVER_METHOD:?Missing SSSERVER_METHOD in ${ENV_FILE}}"
: "${SSSERVER_PASSWORD:?Missing SSSERVER_PASSWORD in ${ENV_FILE}}"

encoded="$(printf '%s' "${SSSERVER_METHOD}:${SSSERVER_PASSWORD}" | base64 | tr -d '\n=')"
printf 'ss://%s@%s:%s#%s\n' "${encoded}" "${SSSERVER_PUBLIC_HOST}" "${SSSERVER_PORT}" "${CONFIG_NAME}"
