# GitOps model

## Principles
- Git is the source of truth.
- Host reconciles periodically.
- Runtime data stays on the host under `/srv/...` (not in Git).
- Secrets are not committed (use host `.env` or SOPS later).

## Change flow
1. Create a branch
2. Edit compose/config
3. Commit + push
4. Merge to `main`
5. Host pulls and applies automatically

## Rollback
- Revert the commit in Git
- Host reconciles back to the previous desired state

## Local domain

Local DNS zone: `aegirshus`

Service hostnames follow the pattern:

- jellyfin.aegirshus
- paperless.aegirshus
- wazuh.aegirshus
- ha.aegirshus