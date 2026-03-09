# Server Access And Security

## Current state

You currently have one Ubuntu `24.04` server and root access to it.

This is enough to start testing, but it is **not** the final security model.

## Important security note

A root password was shared in chat. Because of that, the safe assumption is:

- the password should be treated as exposed
- after SSH key access is configured, rotate that password

## Recommended target access model

### Step 1. Add SSH key access

Use an SSH key pair for deployment. GitHub Actions will use the private key through repository secrets.

### Step 2. Keep a dedicated deploy path

Default path for this project:

- `/opt/opensocks`

### Step 3. Prefer a non-root deploy user later

For the very first bootstrap, `root` is acceptable.

Target model later:

- create a dedicated `deploy` user
- allow Docker access for that user
- disable password authentication

### Step 4. Harden the host

Minimum hardening after the first successful deploy:

- enable `ufw`
- install `fail2ban`
- disable SSH password auth
- disable direct root login if a deploy user is ready
- keep unattended security updates enabled

## What GitHub Actions will need

Repository secrets:

- `SERVER_HOST`
- `SERVER_PORT`
- `SERVER_USER`
- `SERVER_SSH_PRIVATE_KEY`
- `DEPLOY_PATH`

## Bootstrap sequence

1. install Docker and Compose plugin
2. install Git and basic packages
3. create project directory
4. upload server env file
5. run first deployment

