#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${CLUSTER_DIR}/../.." && pwd)"
BOOTSTRAP_USER_SCRIPT="${CLUSTER_DIR}/bootstrap/bootstrap-user.sh"
BOOTSTRAP_SCRIPT="${CLUSTER_DIR}/bootstrap/bootstrap.sh"
DEPLOY_SCRIPT="${SCRIPT_DIR}/deploy.sh"
ENV_FILE="${CLUSTER_DIR}/.env"
ENV_EXAMPLE_FILE="${CLUSTER_DIR}/mimir.env.example"
PAPERLESS_ENV_FILE="${CLUSTER_DIR}/apps/paperless/paperless.env"
PAPERLESS_ENV_EXAMPLE_FILE="${CLUSTER_DIR}/apps/paperless/paperless.env.example"

GENERATED_ITEMS=()

pending() {
  echo "[PENDING] $1"
}

success() {
  echo "[SUCCESS] $1"
}

fail() {
  local step="$1"
  local details="${2:-}"
  echo "[FAILURE] ${step}"
  if [[ -n "$details" ]]; then
    echo "$details"
  fi
  exit 1
}

run_step() {
  local step="$1"
  shift

  pending "$step"

  local output
  if output="$("$@" 2>&1)"; then
    success "$step"
  else
    fail "$step" "$output"
  fi
}

run_step_interactive() {
  local step="$1"
  shift

  pending "$step"

  if "$@"; then
    success "$step"
  else
    fail "$step" "Interactive step failed."
  fi
}

require_command() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 || return 1
}

get_env_value() {
  local file_path="$1"
  local key="$2"
  local value

  value="$(grep -m1 "^${key}=" "$file_path" | cut -d'=' -f2- || true)"
  echo "$value"
}

set_env_value() {
  local file_path="$1"
  local key="$2"
  local value="$3"

  if grep -q "^${key}=" "$file_path"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file_path"
  else
    echo "${key}=${value}" >> "$file_path"
  fi
}

is_valid_hostname() {
  local value="$1"
  [[ "$value" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]
}

is_valid_domain() {
  local value="$1"
  [[ "$value" =~ ^[a-zA-Z0-9.-]+$ ]] && [[ "$value" == *.* ]]
}

is_valid_absolute_path() {
  local value="$1"
  [[ "$value" == /* ]]
}

is_valid_timezone() {
  local value="$1"

  if require_command timedatectl; then
    timedatectl list-timezones | grep -Fxq "$value"
  else
    [[ "$value" =~ ^[A-Za-z_]+/[A-Za-z_+-]+$ ]]
  fi
}

prompt_for_value() {
  local prompt_text="$1"
  local default_value="$2"
  local validator_name="$3"
  local value

  while true; do
    if [[ -n "$default_value" ]]; then
      read -r -p "$prompt_text [$default_value]: " value
      value="${value:-$default_value}"
    else
      read -r -p "$prompt_text: " value
    fi

    if "$validator_name" "$value"; then
      echo "$value"
      return 0
    fi

    echo "Invalid value. Please try again."
  done
}

ensure_file_from_example() {
  local target_file="$1"
  local example_file="$2"

  if [[ ! -f "$target_file" ]]; then
    cp "$example_file" "$target_file"
  fi
}

generate_secret_hex() {
  local bytes="$1"

  if require_command openssl; then
    openssl rand -hex "$bytes"
  else
    head -c "$bytes" /dev/urandom | xxd -p -c "$bytes"
  fi
}

check_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Run as root (sudo bash clusters/skirnir/scripts/first-run.sh)."
    return 1
  fi

  return 0
}

check_repo_layout() {
  [[ -f "$BOOTSTRAP_USER_SCRIPT" ]] || {
    echo "Missing file: $BOOTSTRAP_USER_SCRIPT"
    return 1
  }
  [[ -f "$BOOTSTRAP_SCRIPT" ]] || {
    echo "Missing file: $BOOTSTRAP_SCRIPT"
    return 1
  }
  [[ -f "$DEPLOY_SCRIPT" ]] || {
    echo "Missing file: $DEPLOY_SCRIPT"
    return 1
  }
  [[ -f "$ENV_EXAMPLE_FILE" ]] || {
    echo "Missing file: $ENV_EXAMPLE_FILE"
    return 1
  }
  [[ -f "$PAPERLESS_ENV_EXAMPLE_FILE" ]] || {
    echo "Missing file: $PAPERLESS_ENV_EXAMPLE_FILE"
    return 1
  }
  git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "Repository root is not a git work tree: $REPO_ROOT"
    return 1
  }
  return 0
}

precheck_commands() {
  local required_commands=(git sed grep cut cp id bash)
  local missing_commands=()
  local cmd

  for cmd in "${required_commands[@]}"; do
    if ! require_command "$cmd"; then
      missing_commands+=("$cmd")
    fi
  done

  if [[ "${#missing_commands[@]}" -gt 0 ]]; then
    echo "Missing required commands: ${missing_commands[*]}"
    return 1
  fi

  if ! require_command openssl && ! require_command xxd; then
    echo "Missing required command for secret generation: install openssl (preferred) or xxd."
    return 1
  fi

  return 0
}

collect_missing_config() {
  local current_hostname
  local current_domain
  local current_tz
  local current_media_path
  local current_downloads_path
  local current_docker_data
  local current_paperless_path

  current_hostname="$(get_env_value "$ENV_FILE" "HOSTNAME")"
  current_domain="$(get_env_value "$ENV_FILE" "DOMAIN")"
  current_tz="$(get_env_value "$ENV_FILE" "TZ")"
  current_media_path="$(get_env_value "$ENV_FILE" "MEDIA_PATH")"
  current_downloads_path="$(get_env_value "$ENV_FILE" "DOWNLOADS_PATH")"
  current_docker_data="$(get_env_value "$ENV_FILE" "DOCKER_DATA")"
  current_paperless_path="$(get_env_value "$ENV_FILE" "PAPERLESS_PATH")"

  if [[ -z "$current_hostname" ]] || ! is_valid_hostname "$current_hostname"; then
    current_hostname="$(prompt_for_value "Enter HOSTNAME" "$(hostname -s)" is_valid_hostname)"
    set_env_value "$ENV_FILE" "HOSTNAME" "$current_hostname"
  fi

  if [[ -z "$current_domain" ]] || ! is_valid_domain "$current_domain"; then
    current_domain="$(prompt_for_value "Enter DOMAIN" "aegirshus" is_valid_domain)"
    set_env_value "$ENV_FILE" "DOMAIN" "$current_domain"
  fi

  if [[ -z "$current_tz" ]] || ! is_valid_timezone "$current_tz"; then
    local tz_default
    tz_default="Europe/Stockholm"
    if require_command timedatectl; then
      tz_default="$(timedatectl show -p Timezone --value 2>/dev/null || echo "Europe/Stockholm")"
    fi
    current_tz="$(prompt_for_value "Enter TZ" "$tz_default" is_valid_timezone)"
    set_env_value "$ENV_FILE" "TZ" "$current_tz"
  fi

  if [[ -z "$current_media_path" ]] || ! is_valid_absolute_path "$current_media_path"; then
    current_media_path="$(prompt_for_value "Enter MEDIA_PATH" "/mnt/media" is_valid_absolute_path)"
    set_env_value "$ENV_FILE" "MEDIA_PATH" "$current_media_path"
  fi

  if [[ -z "$current_downloads_path" ]] || ! is_valid_absolute_path "$current_downloads_path"; then
    current_downloads_path="$(prompt_for_value "Enter DOWNLOADS_PATH" "/mnt/torrentdownloads" is_valid_absolute_path)"
    set_env_value "$ENV_FILE" "DOWNLOADS_PATH" "$current_downloads_path"
  fi

  if [[ -z "$current_docker_data" ]] || ! is_valid_absolute_path "$current_docker_data"; then
    current_docker_data="$(prompt_for_value "Enter DOCKER_DATA" "/srv/docker" is_valid_absolute_path)"
    set_env_value "$ENV_FILE" "DOCKER_DATA" "$current_docker_data"
  fi

  if [[ -z "$current_paperless_path" ]] || ! is_valid_absolute_path "$current_paperless_path"; then
    current_paperless_path="$(prompt_for_value "Enter PAPERLESS_PATH" "/srv/paperless" is_valid_absolute_path)"
    set_env_value "$ENV_FILE" "PAPERLESS_PATH" "$current_paperless_path"
  fi

  set_env_value "$ENV_FILE" "DNS_HOST" "dns.${current_domain}"
  set_env_value "$ENV_FILE" "JELLYFIN_HOST" "jellyfin.${current_domain}"
  set_env_value "$ENV_FILE" "PAPERLESS_HOST" "paperless.${current_domain}"
  set_env_value "$ENV_FILE" "HOMEASSISTANT_HOST" "ha.${current_domain}"
  set_env_value "$ENV_FILE" "WAZUH_HOST" "wazuh.${current_domain}"
  set_env_value "$ENV_FILE" "HOMEPAGE_HOST" "home.${current_domain}"
  set_env_value "$ENV_FILE" "PORTAINER_HOST" "portainer.${current_domain}"
  set_env_value "$ENV_FILE" "PROWLARR_HOST" "prowlarr.${current_domain}"
  set_env_value "$ENV_FILE" "SONARR_HOST" "sonarr.${current_domain}"
  set_env_value "$ENV_FILE" "RADARR_HOST" "radarr.${current_domain}"
  set_env_value "$ENV_FILE" "BAZARR_HOST" "bazarr.${current_domain}"
  set_env_value "$ENV_FILE" "QBITTORRENT_HOST" "qbittorrent.${current_domain}"
}

ensure_secrets() {
  local db_pass
  local paperless_secret
  local paperless_url
  local domain

  domain="$(get_env_value "$ENV_FILE" "DOMAIN")"

  db_pass="$(get_env_value "$ENV_FILE" "PAPERLESS_DBPASS")"
  if [[ -z "$db_pass" ]]; then
    db_pass="$(generate_secret_hex 24)"
    set_env_value "$ENV_FILE" "PAPERLESS_DBPASS" "$db_pass"
    GENERATED_ITEMS+=("PAPERLESS_DBPASS (.env): $db_pass")
  fi

  paperless_secret="$(get_env_value "$PAPERLESS_ENV_FILE" "PAPERLESS_SECRET_KEY")"
  if [[ -z "$paperless_secret" || "$paperless_secret" == "CHANGE_ME_TO_A_LONG_RANDOM_STRING" ]]; then
    paperless_secret="$(generate_secret_hex 32)"
    set_env_value "$PAPERLESS_ENV_FILE" "PAPERLESS_SECRET_KEY" "$paperless_secret"
    GENERATED_ITEMS+=("PAPERLESS_SECRET_KEY (paperless.env): $paperless_secret")
  fi

  paperless_url="$(get_env_value "$PAPERLESS_ENV_FILE" "PAPERLESS_URL")"
  if [[ -z "$paperless_url" || "$paperless_url" == "http://paperless.aegirshus" ]]; then
    set_env_value "$PAPERLESS_ENV_FILE" "PAPERLESS_URL" "http://paperless.${domain}"
  fi
}

main() {
  run_step "Check root privileges" check_root
  run_step "Check required commands" precheck_commands
  run_step "Check repository layout" check_repo_layout
  run_step "Ensure .env exists" ensure_file_from_example "$ENV_FILE" "$ENV_EXAMPLE_FILE"
  run_step "Ensure paperless.env exists" ensure_file_from_example "$PAPERLESS_ENV_FILE" "$PAPERLESS_ENV_EXAMPLE_FILE"
  run_step_interactive "Collect and validate missing config" collect_missing_config
  run_step "Generate and validate required secrets" ensure_secrets
  run_step "Run bootstrap-user.sh" bash "$BOOTSTRAP_USER_SCRIPT"
  run_step "Run bootstrap.sh" bash "$BOOTSTRAP_SCRIPT"
  run_step "Run deploy.sh" env REPO_DIR="$REPO_ROOT" bash "$DEPLOY_SCRIPT"

  if [[ "${#GENERATED_ITEMS[@]}" -gt 0 ]]; then
    echo "SAVE THESE SECRETS NOW:"
    for item in "${GENERATED_ITEMS[@]}"; do
      echo "$item"
    done
  fi
}

main "$@"
