# Project Inputs

Этот файл нужен, чтобы хранить исходные решения и параметры проекта в одном месте.

## Git

- Remote URL: `https://github.com/KatamaranSSS/opensocks.git`
- Default branch: `main`
- Deployment model:
  - [ ] manual pull on servers
  - [x] deploy via CI
  - [ ] self-hosted runner
  - [x] other

Recommended model: `GitHub Actions -> tests -> Docker image build -> registry push -> SSH deploy to Docker hosts`

## Servers

### Server 1

- Role: `test`
- Host/IP:
- SSH port: `22`
- SSH user:
- OS:
- Deploy path:

### Server 2

- Role: `test`
- Host/IP:
- SSH port: `22`
- SSH user:
- OS:
- Deploy path:

## Domains

- API domain:
- Panel domain:
- Public landing domain:

## Product

- First client platforms: `macOS`
- Control panel required: yes / no
- Control panel required: `yes`
- Multi-user support required:
- Need billing: yes / no
- Need traffic quotas: yes / no

## Tech decisions

- Backend stack: `Python` proposed by user, final recommendation pending
- Client stack: open question
- Database:
- Proxy implementation: recommended `shadowsocks-rust`

## Current interpretation of open questions

- Auto deploy is required
- Docker is mandatory
- Initial topology: `test + test`
- Future topology: `prod + failover`
- Domains are not purchased yet
- Server provider is not selected yet
- `Multi-user support` means whether the system should manage multiple separate end users, each with their own access, configs, limits and activity history
- `Client stack` means whether we build:
  - one cross-platform app with shared UI
  - a native macOS app first and separate native apps later

## Notes

- Need to choose provider, regions and minimum instance size before infra work starts
- Need to choose client architecture before app scaffold starts
- Need to confirm whether billing/quotas are in MVP
