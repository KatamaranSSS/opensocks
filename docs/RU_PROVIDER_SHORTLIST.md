# RU Provider Shortlist

Date reference: `2026-03-09`

This shortlist is focused on:

- billing in rubles
- RU-first audience
- VPS/VDS suitable for early OpenSocks rollout

## 1. Timeweb Cloud

Good default if you want a cleaner product experience and predictable scaling.

Examples from the public pricing page:

- `Cloud MSK 15`: `1 vCPU`, `1 GB RAM`, `15 GB NVMe`, `477 ₽/month`
- `Cloud MSK 30`: `1 vCPU`, `2 GB RAM`, `30 GB NVMe`, `657 ₽/month`
- `Cloud MSK 50`: `2 vCPU`, `4 GB RAM`, `50 GB NVMe`, `1 062 ₽/month`

Observed RU locations on the public status page include:

- `msk-1`
- `spb-1`
- `spb-2`
- `spb-3`
- `spb-4`
- `nsk-1`

## 2. Selectel

Strong option if you want a serious Russian infrastructure provider with multiple own data centers.

Public documentation currently states:

- base cloud servers start from `1 vCPU`, `1 GB RAM`, `16 GB disk`
- own Tier III data centers in `Moscow`, `Saint Petersburg` and `Leningrad Region`

## 3. VDSina

Very price-aggressive option for cheap test nodes.

Examples from the public pricing page:

- `1 core`, `1 GB RAM`, `10 GB`, `150 ₽/month`
- `1 core`, `2 GB RAM`, `50 GB`, `600 ₽/month`
- `2 core`, `4 GB RAM`, `100 GB`, `1 200 ₽/month`

## 4. RuVDS

Useful when you want many Russian and foreign locations and cheap entry pricing.

Examples from public pages:

- `Старт`: `1 CPU`, `512 MB RAM`, `10 GB`, `139 ₽/month`
- `Старт SSD`: `1 CPU`, `512 MB RAM`, `10 GB SSD`, `209 ₽/month`
- `Турбо 1`: `2 CPU`, `4 GB RAM`, `40 GB SSD`, `1 099 ₽/month` when paid for 3 months

Public materials also mention locations such as:

- `Moscow`
- `Saint Petersburg`
- `Kazan`
- `Yekaterinburg`
- `Novosibirsk`
- `Vladivostok`

## Recommended purchase path

### Lowest-risk option

- `Server 1`: `Timeweb Cloud MSK 50` or similar
- `Server 2`: `Timeweb Cloud MSK 30` / SPB equivalent or `VDSina 1 core / 2 GB`

### Lowest-budget option

- `Server 1`: `Timeweb Cloud MSK 30` or `VDSina 1 core / 2 GB`
- `Server 2`: `VDSina 1 core / 1 GB` or `RuVDS Старт SSD`

### Best operational balance for your architecture

- `Server 1` control plane: `2 vCPU / 4 GB`
- `Server 2` proxy node: `1 vCPU / 2 GB`

This is the recommended baseline for your current `multi-user + Docker + backend + admin` scope.
