#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/opt/homelab}"
BRANCH="${BRANCH:-main}"
REMOTE="${REMOTE:-origin}"

cd "$REPO_DIR"

echo "[reconcile] Fetching git state..."
git fetch --all --prune
git reset --hard "${REMOTE}/${BRANCH}"

# Ensure proxy network exists (safe if already exists)
docker network create proxy >/dev/null 2>&1 || true

# Env: compose should load clusters/skirnir/.env
cd clusters/skirnir

# Apply stacks (order matters a bit: proxy before UIs, etc.)
STACKS=(
  "apps/proxy/compose.yaml"
  "apps/dns/compose.yaml"
  "apps/homeassistant/compose.yaml"
  "apps/homepage/compose.yaml"
  "apps/portainer/compose.yaml"
  "apps/jellyfin/compose.yaml"
  "apps/arr/compose.yaml"
  "apps/paperless/compose.yaml"
)

for f in "${STACKS[@]}"; do
  echo "[reconcile] Applying $f"
  docker compose --env-file .env -f "$f" pull
  docker compose --env-file .env -f "$f" up -d --remove-orphans
done

echo "[reconcile] Done."