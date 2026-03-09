# Infrastructure Guide

## Target starting point

Start with 2 small but not tiny VPS instances:

- `server-1`: test
- `server-2`: test

Later convert the same model to:

- `server-1`: production
- `server-2`: failover

## Recommended minimum server profile

For early testing:

- `2 vCPU`
- `2 GB RAM`
- `40-60 GB SSD`
- stable outbound bandwidth
- Ubuntu `24.04 LTS`

For later production:

- `2-4 vCPU`
- `4 GB RAM`
- `60+ GB SSD`
- snapshots/backups enabled

## Recommended providers to compare

- `Hetzner Cloud`: usually best price/performance if the needed region fits
- `DigitalOcean`: simpler UX and many guides, usually more expensive
- `Vultr`: broad region coverage and straightforward VPS model

## Region strategy

Pick regions based on where the users are physically located.

Starting recommendation:

- one European region
- one US region

If your first users are mostly in Russia/CIS, nearby European locations are usually the first place to test. Do not commit to one geography before checking latency and legal risk for your target audience.

## What to verify before buying

- VPS policy toward proxy software
- available snapshots/backups
- IPv4 availability
- DDoS posture
- upgrade path to larger instances
- whether Docker is allowed without restrictions

## Domains and DNS later

You will need at least:

- one domain for API
- one domain for admin panel

Optional later:

- landing site domain
- separate status domain

