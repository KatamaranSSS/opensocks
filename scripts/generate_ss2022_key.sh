#!/usr/bin/env bash
set -euo pipefail

METHOD="${1:-2022-blake3-aes-128-gcm}"

case "${METHOD}" in
  2022-blake3-aes-128-gcm)
    bytes=16
    ;;
  2022-blake3-aes-256-gcm|2022-blake3-chacha20-poly1305)
    bytes=32
    ;;
  *)
    echo "Unsupported SS2022 method: ${METHOD}" >&2
    echo "Supported: 2022-blake3-aes-128-gcm, 2022-blake3-aes-256-gcm, 2022-blake3-chacha20-poly1305" >&2
    exit 1
    ;;
esac

openssl rand -base64 "${bytes}" | tr -d '\n'
echo
