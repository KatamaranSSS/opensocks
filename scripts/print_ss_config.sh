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

urlencode() {
  local raw="${1}"
  raw="${raw//%/%25}"
  raw="${raw// /%20}"
  raw="${raw//;/%3B}"
  raw="${raw//=/%3D}"
  raw="${raw//\//%2F}"
  raw="${raw//#/%23}"
  raw="${raw//:/%3A}"
  printf '%s' "${raw}"
}

encoded="$(printf '%s' "${SSSERVER_METHOD}:${SSSERVER_PASSWORD}" | base64 | tr -d '\n=')"
SSSERVER_OBFS_ENABLED="${SSSERVER_OBFS_ENABLED:-false}"

if [[ "${SSSERVER_OBFS_ENABLED}" == "true" ]]; then
  SSSERVER_PLUGIN="${SSSERVER_PLUGIN:-v2ray-plugin}"
  SSSERVER_OBFS_MODE="${SSSERVER_OBFS_MODE:-websocket}"
  SSSERVER_OBFS_PATH="${SSSERVER_OBFS_PATH:-/ws}"
  SSSERVER_OBFS_HOST="${SSSERVER_OBFS_HOST:-}"
  plugin_value="${SSSERVER_PLUGIN};mode=${SSSERVER_OBFS_MODE};path=${SSSERVER_OBFS_PATH}"
  if [[ -n "${SSSERVER_OBFS_HOST}" ]]; then
    plugin_value="${plugin_value};host=${SSSERVER_OBFS_HOST}"
  fi
  plugin_encoded="$(urlencode "${plugin_value}")"
  printf 'ss://%s@%s:%s/?plugin=%s#%s\n' \
    "${encoded}" "${SSSERVER_PUBLIC_HOST}" "${SSSERVER_PORT}" "${plugin_encoded}" "${CONFIG_NAME}"
else
  printf 'ss://%s@%s:%s#%s\n' "${encoded}" "${SSSERVER_PUBLIC_HOST}" "${SSSERVER_PORT}" "${CONFIG_NAME}"
fi
