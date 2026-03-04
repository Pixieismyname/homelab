# Storage conventions

## Persistent state
- Container configs/state: `/srv/docker/<stack>/...`
- Shared data:
  - media: `/srv/media` or `/mnt/media` (if remote mount)
  - downloads: `/srv/downloads`
  - paperless: `/srv/paperless`
  - wazuh: `/srv/wazuh`

## Permissions
Prefer consistent ownership for bind mounts (typically the main admin user).
If a container needs specific UID/GID, document it in the stack README.