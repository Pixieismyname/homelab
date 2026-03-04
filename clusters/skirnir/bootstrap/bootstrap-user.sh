#!/usr/bin/env bash
set -euo pipefail

########################################
# Skirnir GitOps user bootstrap
########################################

GITOPS_USER="gitops"
REPO_DIR="/opt/homelab"
DATA_ROOT="/srv"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash bootstrap-user.sh"
  exit 1
fi

echo "==== Skirnir GitOps user setup ===="

########################################
# Create gitops user if missing
########################################

if id "$GITOPS_USER" &>/dev/null; then
  echo "User $GITOPS_USER already exists"
else
  echo "Creating user: $GITOPS_USER"
  useradd -m -s /bin/bash "$GITOPS_USER"
fi

########################################
# Add user to docker group
########################################

echo "Adding $GITOPS_USER to docker group"

groupadd docker >/dev/null 2>&1 || true
usermod -aG docker "$GITOPS_USER"

########################################
# Prepare repo directory
########################################

echo "Preparing repo directory: $REPO_DIR"

mkdir -p "$REPO_DIR"
chown -R "$GITOPS_USER":"$GITOPS_USER" "$REPO_DIR"

########################################
# Prepare data directories
########################################

echo "Preparing /srv directories"

mkdir -p $DATA_ROOT/docker
mkdir -p $DATA_ROOT/media
mkdir -p $DATA_ROOT/downloads
mkdir -p $DATA_ROOT/paperless

chown -R "$GITOPS_USER":"$GITOPS_USER" $DATA_ROOT

########################################
# Ensure docker access works
########################################

echo "Testing docker access for $GITOPS_USER"

sudo -u "$GITOPS_USER" docker version >/dev/null 2>&1 || {
  echo "Docker not ready yet or requires relogin."
}

########################################
# Done
########################################

echo ""
echo "Bootstrap user setup complete."
echo ""
echo "Next steps:"
echo "1) Switch to gitops user:"
echo "   sudo su - gitops"
echo ""
echo "2) Clone the repo:"
echo "   git clone <your repo url> /opt/homelab"
echo ""
echo "3) Copy env files:"
echo "   cp clusters/skirnir/mimir.env.example clusters/skirnir/.env"
echo "   cp clusters/skirnir/apps/paperless/paperless.env.example clusters/skirnir/apps/paperless/paperless.env"
echo ""
echo "4) Run the main bootstrap:"
echo "   sudo bash clusters/skirnir/bootstrap/bootstrap.sh"
echo ""