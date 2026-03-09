# Server Sizing

## Short answer

Both statements can be true.

`1 vCPU / 512 MB RAM` can be enough for a **single lightweight Shadowsocks proxy process** with a very small number of users and no additional platform services.

It is **not** a good default for your target architecture, because you are not building only a proxy daemon. You are building:

- `Shadowsocks` proxy
- backend API
- admin panel
- database
- Docker runtime
- logs, updates, health checks
- multi-user control plane

## Why the cheapest VPS is not the right baseline here

### Case A. Proxy-only node

This is the scenario where the "cheapest VPS is enough" advice is often correct:

- one proxy process
- no database
- no admin panel
- no control plane
- no multi-user logic
- no Docker-heavy stack

For this mode, a test node can often start from:

- `1 vCPU`
- `1 GB RAM`
- `20-30 GB SSD`

`512 MB` can work for very small tests, but it leaves almost no headroom for spikes, logs, updates and Docker overhead.

### Case B. Your actual product

Your project is different:

- private multi-user service
- automatic deploys
- Docker-based runtime
- backend and admin panel
- future production + failover

For this mode, the control plane server should have real headroom.

## Recommended split for your current budget-sensitive start

Instead of making both servers equally large, I recommend a split-role setup:

### Server 1: control plane + API + DB + admin + optional proxy

- `2 vCPU`
- `4 GB RAM`
- `40-60 GB SSD`

Why:

- database memory floor
- Docker + reverse proxy + app containers
- admin panel and API
- safer updates and less swap pressure

### Server 2: proxy-only test node

- `1 vCPU`
- `1-2 GB RAM`
- `20-40 GB SSD`

Why:

- enough for realistic throughput tests
- cheaper than making both hosts oversized
- clean separation between control plane and proxy traffic

## If you want the absolute minimum to start

You can start with **two small test servers** like:

- `1 vCPU`
- `1 GB RAM`
- `20-30 GB SSD`

This is acceptable for early tests if:

- traffic is low
- users are few
- monitoring is minimal
- you accept that one of the nodes may need resizing soon

I do **not** recommend `512 MB` as the base size for a Dockerized multi-service project.

## RU-first provider guidance

For your constraints, the default shortlist should be:

- `Timeweb Cloud`
- `Selectel`
- `RuVDS`
- `VDSina`

Recommended practical choice:

- `Timeweb Cloud` or `Selectel` for the main control-plane server
- `Timeweb Cloud`, `RuVDS` or `VDSina` for cheap proxy test nodes

## Initial RU-only region strategy

Because your first users are in Russia, start with two Russian locations:

- `Moscow`
- `Saint Petersburg`

This gives you:

- low latency for the first audience
- simple ruble billing
- easier legal and operational setup

## Important caveat

This sizing is for **service quality and operational headroom**, not because Shadowsocks itself is extremely heavy.

The expensive part in your architecture is not the proxy daemon alone. It is the platform around it.
