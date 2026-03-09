# Deployment Strategy

## Recommended model

Use `GitHub Actions` as the control point for automation.

Pipeline:

1. Push to `main`
2. Run checks and tests
3. Connect to `test-1` over `SSH`
4. Pull the latest revision and run `docker compose up --build -d`
5. Run smoke checks
6. Connect to `test-2` over `SSH`
7. Pull the latest revision and run `docker compose up --build -d`
8. Run smoke checks

Future optimized pipeline:

1. Push to `main`
2. Run checks and tests
3. Build Docker images
4. Push images to a container registry
5. Deploy automatically to `test-1`
6. Run smoke checks
7. Deploy automatically to `test-2`
8. Run smoke checks

Later for production:

1. Merge or release tag
2. Deploy to `prod-1`
3. Verify health
4. Deploy to `failover/prod-2`

## Why this is the best fit here

- no manual `git pull` on servers
- Docker stays the source of runtime consistency
- tests are mandatory before rollout
- rollout can be sequential and safer for 2 hosts
- GitHub-hosted runners keep CI outside the proxy servers

## Recommended components

- CI/CD: `GitHub Actions`
- Runtime on servers: `Docker Compose`
- Secret storage: `GitHub Actions repository secrets`
- Deploy transport: `SSH` from GitHub Actions to servers

Optional later:

- Container registry: `GHCR` or another registry when plan limits are no longer a constraint

## Why not self-hosted runners on the servers

Self-hosted runners add maintenance and security overhead on the same hosts that will run the proxy stack. For an internet-facing service, this is a worse default than GitHub-hosted runners plus SSH deploy.

## Why the initial version should avoid GHCR

On `GitHub Free`, private repositories have limited included `Actions` minutes and limited shared storage. Public GitHub billing docs state that the included storage is shared between `Actions` artifacts, caches and `GitHub Packages`.

For the first stage, this makes direct server-side Docker builds simpler and cheaper than maintaining private image storage in `GHCR`.

## Required secrets later

- `SSH_PRIVATE_KEY`
- `TEST_SERVER_1_HOST`
- `TEST_SERVER_1_USER`
- `TEST_SERVER_2_HOST`
- `TEST_SERVER_2_USER`
- registry token if needed

## Private repository note

This repository is private and the current GitHub account does not use `GitHub Pro`.

Because of that, the first implementation should rely on:

- repository-level `Actions Secrets`
- repository-level workflows

Do not assume protected deployment environments are available for the first version.

## Required server-side software

- Docker Engine
- Docker Compose plugin
- OpenSSH server
- firewall rules

## Open decisions

- exact registry namespace
- whether test servers deploy on every push or only on `main`
- smoke check endpoints and health criteria
