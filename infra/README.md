# Infrastructure Notes

This directory stores deployment-related preparation for two servers.

## Planned layout

- `servers.example.env` - template with required server and git settings
- future deploy scripts
- future provisioning notes

## Target model

- `server-1`: first test target
- `server-2`: second test target / failover candidate

## Planned deployment flow

1. Push changes to git
2. Pull/update on target servers or trigger CI-based deploy
3. Restart services safely
4. Verify health checks on both servers

