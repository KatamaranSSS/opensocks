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

## Recommended providers for your current constraints

Because the first audience is in Russia and billing in rubles is required, start with Russian-friendly providers first:

- `Timeweb Cloud`
- `Selectel`
- `RuVDS`
- `VDSina`

Practical default:

- `Timeweb Cloud` or `Selectel` for the first main server
- `RuVDS` or `VDSina` as cheaper test-node alternatives if needed

## Region strategy

Pick regions based on where the users are physically located.

Starting recommendation for the current phase:

- `Moscow`
- `Saint Petersburg`

When the product expands beyond RU-only usage, revisit the topology and add foreign regions.

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
