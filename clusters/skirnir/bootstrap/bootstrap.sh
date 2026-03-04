
### 2) `clusters/skirnir/bootstrap/bootstrap.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# ---- Settings you may change ----
REPO_DIR_DEFAULT="/opt/homelab"
GIT_REMOTE_DEFAULT="origin"
GIT_BRANCH_DEFAULT="main"
# --------------------------------

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash bootstrap.sh"
  exit 1
fi

echo "[1/8] Base packages"
apt-get update
apt-get install -y ca-certificates curl gnupg git openssh-server cifs-utils

echo "[2/8] Disable sleep/hibernate (laptop server)"
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target || true

echo "[3/8] Install Docker Engine (official repo)"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

. /etc/os-release
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[4/8] Enable Docker at boot"
systemctl enable --now docker

echo "[5/8] Create /srv structure"
mkdir -p /srv/docker
mkdir -p /srv/{media,downloads,paperless}
# Wazuh later:
mkdir -p /srv/wazuh || true

echo "[6/8] Create shared Docker network: proxy"
# It's OK if it already exists
docker network create proxy >/dev/null 2>&1 || true

echo "[7/8] Install reconcile script"
install -m 0755 -d /opt/homelab
# We don't clone here because you may prefer to clone with your user.
# The systemd unit will run reconcile.sh which uses REPO_DIR env.

echo "[8/8] Install systemd units"
install -m 0644 ./systemd/skirnir-reconcile.service /etc/systemd/system/skirnir-reconcile.service
install -m 0644 ./systemd/skirnir-reconcile.timer /etc/systemd/system/skirnir-reconcile.timer

systemctl daemon-reload
systemctl enable --now skirnir-reconcile.timer

cat <<EOF

Bootstrap complete.

Next:
1) Clone your repo to ${REPO_DIR_DEFAULT}
2) Copy clusters/skirnir/mimir.env.example to clusters/skirnir/.env
3) Create clusters/skirnir/apps/paperless/paperless.env from example
4) The timer will reconcile automatically.

EOF