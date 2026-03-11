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

source "${ENV_FILE}"
: "${SS2022_METHOD:?Missing SS2022_METHOD in ${ENV_FILE}}"

mkdir -p "$(dirname "${USERS_FILE}")"
touch "${USERS_FILE}"

existing="$(awk -F: -v target="${USERNAME}" '$1 == target {print $2; exit}' "${USERS_FILE}")"
if [[ -n "${existing}" ]]; then
  bash "$(dirname "$0")/print_ss2022_config.sh" "${USERNAME}" "${ENV_FILE}" "${USERS_FILE}"
  exit 0
fi

user_key="$(bash "$(dirname "$0")/generate_ss2022_key.sh" "${SS2022_METHOD}")"
printf '%s:%s\n' "${USERNAME}" "${user_key}" >>"${USERS_FILE}"

bash "$(dirname "$0")/print_ss2022_config.sh" "${USERNAME}" "${ENV_FILE}" "${USERS_FILE}"
