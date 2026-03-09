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
- Control panel required: `yes`
- Multi-user support required: `yes`
- Need billing: yes / no
- Need traffic quotas: yes / no

## Tech decisions

- Backend stack: `Python + FastAPI`
- Client stack: `native macOS app on SwiftUI`
- Database:
- Proxy implementation: `shadowsocks-rust`

## Current interpretation of open questions

- Auto deploy is required
- Docker is mandatory
- Initial topology: `test + test`
- Future topology: `prod + failover`
- Domains are not purchased yet
- Server provider is not selected yet
- Repository visibility: `private`
- GitHub plan: `Free`, without `GitHub Pro`
- First audience geography: `RU`

## Notes

- Need to choose provider, regions and minimum instance size before infra work starts
- Billing and traffic quotas are still not confirmed for MVP
- GitHub environments for private repositories are not available on GitHub Free, so deployment will rely on repository secrets instead of environment secrets
