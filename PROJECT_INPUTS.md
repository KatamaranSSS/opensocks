# Project Inputs

Этот файл теперь хранит только то, что нужно для простого сервисного `Shadowsocks`-варианта.

## Git

- Remote URL: `https://github.com/KatamaranSSS/opensocks.git`
- Default branch: `main`
- Deploy model: `GitHub Actions -> SSH -> docker compose up -d`

## Current server

- Role: `single-server-test`
- Host/IP: `109.71.246.216`
- SSH port: `22`
- SSH user: `root`
- OS: `Ubuntu 24.04`
- Deploy path: `/opt/opensocks`

## Product scope

- No custom client
- No panel
- No backend
- No subscriptions
- Config delivery format: plain text `ss://...`
- First goal: one guaranteed working config in a third-party client

## Tech decisions

- Proxy implementation: `shadowsocks-rust`
- Runtime: `Docker Compose`
- Cipher: `chacha20-ietf-poly1305`
- Server mode target: `tcp_and_udp`

## Notes

- The previous backend and macOS app were intentionally removed from the active scope.
- The working criterion is no longer local `curl`, but a real third-party client that opens blocked sites through the VPS.
- Root password must not be stored in the repository.
