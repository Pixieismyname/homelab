#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/opt/homelab}"
BRANCH="${BRANCH:-main}"
REMOTE="${REMOTE:-origin}"

require_cmd() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "[reconcile] Missing required command: $command_name"
    exit 1
  }
}

merge_missing_env_keys() {
  local source_file="$1"
  local target_file="$2"
  local line
  local key
  local added_count=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" != *"="* ]] && continue

    key="${line%%=*}"
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

    if ! grep -q "^${key}=" "$target_file"; then
      echo "$line" >> "$target_file"
      added_count=$((added_count + 1))
      echo "[reconcile] Added missing .env key: $key"
    fi
  done < "$source_file"

  if [[ "$added_count" -eq 0 ]]; then
    echo "[reconcile] .env already has all keys from $source_file"
  fi
}

ensure_directory() {
  local path="$1"

  [[ -n "$path" ]] || return 0

  if [[ -d "$path" ]]; then
    echo "[reconcile] Storage exists: $path"
    return 0
  fi

  mkdir -p "$path"
  echo "[reconcile] Created storage directory: $path"
}

ensure_mount_if_needed() {
  local path="$1"

  [[ -n "$path" ]] || return 0

  if mountpoint -q "$path"; then
    echo "[reconcile] Mount exists: $path"
    return 0
  fi

  if [[ "$path" == /mnt/* ]]; then
    echo "[reconcile] Mount missing at $path, attempting mount"
    if mount "$path"; then
      echo "[reconcile] Mounted: $path"
      return 0
    fi

    echo "[reconcile] Failed to mount: $path"
    exit 1
  fi

  echo "[reconcile] Not a mount path, skip mount: $path"
}

require_cmd git
require_cmd docker
require_cmd mountpoint

if [[ ! -d "$REPO_DIR" ]]; then
  echo "[reconcile] REPO_DIR does not exist: $REPO_DIR"
  exit 1
fi

cd "$REPO_DIR"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "[reconcile] Not a git repository: $REPO_DIR"
  exit 1
}

echo "[reconcile] Fetching git state..."
git fetch "$REMOTE" --prune

if ! git show-ref --verify --quiet "refs/remotes/${REMOTE}/${BRANCH}"; then
  echo "[reconcile] Remote branch not found: ${REMOTE}/${BRANCH}"
  exit 1
fi

git checkout -B "$BRANCH" "${REMOTE}/${BRANCH}"
git reset --hard "${REMOTE}/${BRANCH}"
echo "[reconcile] Using commit $(git rev-parse --short HEAD)"

# Ensure proxy network exists (safe if already exists)
docker network create proxy >/dev/null 2>&1 || true

# Env: compose should load clusters/skirnir/.env
cd clusters/skirnir

if [[ ! -f .env ]]; then
  echo "[reconcile] Missing env file: $REPO_DIR/clusters/skirnir/.env"
  exit 1
fi

if [[ ! -f mimir.env.example ]]; then
  echo "[reconcile] Missing env template: $REPO_DIR/clusters/skirnir/mimir.env.example"
  exit 1
fi

merge_missing_env_keys "mimir.env.example" ".env"

set -a
# shellcheck disable=SC1091
source .env
set +a

STORAGE_PATHS=(
  "${DOCKER_DATA:-}"
  "${PAPERLESS_PATH:-}"
  "${WAZUH_PATH:-}"
  "${MEDIA_PATH:-}"
  "${DOWNLOADS_PATH:-}"
)

for path in "${STORAGE_PATHS[@]}"; do
  ensure_directory "$path"
done

MOUNT_CANDIDATES=(
  "${MEDIA_PATH:-}"
  "${DOWNLOADS_PATH:-}"
)

for path in "${MOUNT_CANDIDATES[@]}"; do
  ensure_mount_if_needed "$path"
done

# Apply stacks (order matters a bit: proxy before UIs, etc.)
STACKS=(
  "apps/proxy/compose.yaml"
  "apps/dns/compose.yaml"
  "apps/homeassistant/compose.yaml"
  "apps/homepage/compose.yaml"
  "apps/portainer/compose.yaml"
  "apps/jellyfin/compose.yaml"
  "apps/arr/compose.yaml"
  "apps/flaresolverr/compose.yaml"
  "apps/paperless/compose.yaml"
)

for f in "${STACKS[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "[reconcile] Missing compose file: $f"
    exit 1
  fi

  docker compose --env-file .env -f "$f" config -q

  echo "[reconcile] Applying $f"
  docker compose --env-file .env -f "$f" pull
  docker compose --env-file .env -f "$f" up -d --remove-orphans
done

echo "[reconcile] Done."