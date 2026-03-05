#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
REPO_DIR="${REPO_DIR:-$DEFAULT_REPO_DIR}"

PASS_COUNT=0
FAIL_COUNT=0

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

pending() {
  echo "[PENDING] $1"
}

success() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "[SUCCESS] $1"
}

failure() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  local step="$1"
  local details="${2:-}"
  echo "[FAILURE] $step"
  if [[ -n "$details" ]]; then
    echo "$details"
  fi
}

run_check() {
  local step="$1"
  shift

  pending "$step"

  local output
  if output="$("$@" 2>&1)"; then
    success "$step"
  else
    failure "$step" "$output"
  fi
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd"
    return 1
  }
}

check_compose_file() {
  local compose_file="$1"
  docker compose --env-file .env -f "$compose_file" config -q >/dev/null
}

check_stack_services_running() {
  local compose_file="$1"
  local services
  local service
  local container_id
  local running_state

  services="$(docker compose --env-file .env -f "$compose_file" ps --services)"
  [[ -n "$services" ]] || {
    echo "No services found in $compose_file"
    return 1
  }

  for service in $services; do
    container_id="$(docker compose --env-file .env -f "$compose_file" ps -q "$service")"
    [[ -n "$container_id" ]] || {
      echo "Service '$service' has no running container (stack: $compose_file)"
      return 1
    }

    running_state="$(docker inspect -f '{{.State.Running}}' "$container_id")"
    [[ "$running_state" == "true" ]] || {
      echo "Service '$service' is not running (container: $container_id)"
      return 1
    }
  done
}

check_http_route() {
  local host="$1"
  local code

  code="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 12 -H "Host: $host" http://127.0.0.1 || true)"

  [[ "$code" =~ ^[234][0-9][0-9]$ ]] || {
    echo "HTTP health failed for $host (status: ${code:-none})"
    return 1
  }
}

check_dns_port() {
  local proto="$1"
  docker compose --env-file .env -f apps/dns/compose.yaml port adguard "53/$proto" >/dev/null
}

main() {
  run_check "Command available: docker" require_cmd docker
  run_check "Command available: curl" require_cmd curl

  pending "Resolve repository path"
  if [[ ! -d "$REPO_DIR" ]]; then
    failure "Resolve repository path" "REPO_DIR not found: $REPO_DIR"
  else
    success "Resolve repository path"
  fi

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo ""
    echo "Healthcheck aborted: preflight failed."
    exit 1
  fi

  cd "$REPO_DIR"

  run_check "Repository is a git work tree" git rev-parse --is-inside-work-tree

  pending "Change to cluster directory"
  if cd clusters/skirnir; then
    success "Change to cluster directory"
  else
    failure "Change to cluster directory" "Could not enter clusters/skirnir from $REPO_DIR"
  fi

  pending "Load .env"
  if [[ -f .env ]]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
    success "Load .env"
  else
    failure "Load .env" "Missing file: $REPO_DIR/clusters/skirnir/.env"
  fi

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo ""
    echo "Healthcheck aborted: setup checks failed."
    exit 1
  fi

  local compose_file
  for compose_file in "${STACKS[@]}"; do
    run_check "Compose validates: $compose_file" check_compose_file "$compose_file"
    run_check "Services running: $compose_file" check_stack_services_running "$compose_file"
  done

  run_check "DNS port bound (tcp/53)" check_dns_port tcp
  run_check "DNS port bound (udp/53)" check_dns_port udp

  run_check "HTTP route: ${DNS_HOST}" check_http_route "$DNS_HOST"
  run_check "HTTP route: ${HOMEPAGE_HOST}" check_http_route "$HOMEPAGE_HOST"
  run_check "HTTP route: ${PORTAINER_HOST}" check_http_route "$PORTAINER_HOST"
  run_check "HTTP route: ${JELLYFIN_HOST}" check_http_route "$JELLYFIN_HOST"
  run_check "HTTP route: ${PAPERLESS_HOST}" check_http_route "$PAPERLESS_HOST"
  run_check "HTTP route: ${HOMEASSISTANT_HOST}" check_http_route "$HOMEASSISTANT_HOST"
  run_check "HTTP route: ${PROWLARR_HOST}" check_http_route "$PROWLARR_HOST"
  run_check "HTTP route: ${SONARR_HOST}" check_http_route "$SONARR_HOST"
  run_check "HTTP route: ${RADARR_HOST}" check_http_route "$RADARR_HOST"
  run_check "HTTP route: ${BAZARR_HOST}" check_http_route "$BAZARR_HOST"
  run_check "HTTP route: ${QBITTORRENT_HOST}" check_http_route "$QBITTORRENT_HOST"
  run_check "HTTP route: ${FLARESOLVERR_HOST}" check_http_route "$FLARESOLVERR_HOST"

  echo ""
  echo "Healthcheck summary: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
