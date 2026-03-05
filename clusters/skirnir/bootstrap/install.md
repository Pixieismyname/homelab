# Skirnir install and deployment guide (Ubuntu 24.04)

This guide describes a full first-time deployment on a clean Ubuntu Server host and how to operate it afterward.

## 1) Host preparation (fresh OS)

Install Ubuntu Server 24.04 LTS.

Recommended during OS install:

- Enable OpenSSH server.
- Set hostname to `skirnir`.
- Create an admin user with sudo rights.
- Configure a static DHCP lease (recommended).

After first login, update packages and ensure `git` exists:

```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y git
```

## 2) Clone repository

Clone the repo to `/opt/homelab` (recommended path for service defaults):

```bash
sudo mkdir -p /opt
sudo chown "$USER":"$USER" /opt
cd /opt
git clone <your-repo-url> homelab
cd /opt/homelab
```

If you clone to a different path, update systemd `REPO_DIR` later or pass `REPO_DIR` on manual runs.

## 3) Run first-time bootstrap (recommended path)

Run the orchestrated first-run flow:

```bash
cd /opt/homelab
sudo bash clusters/skirnir/scripts/first-run.sh
```

What it does:

1. Runs prechecks (root, command availability, repo layout).
2. Ensures these files exist (copies from examples if missing):
   - `clusters/skirnir/.env`
   - `clusters/skirnir/apps/paperless/paperless.env`
3. Prompts for missing/invalid values and validates them.
4. Generates required secrets if missing.
5. Runs:
   - `clusters/skirnir/bootstrap/bootstrap-user.sh`
   - `clusters/skirnir/bootstrap/bootstrap.sh`
   - `clusters/skirnir/scripts/deploy.sh`

At the end, save any generated secrets printed by first-run.

## 4) Verify deployment

Check timer and service state:

```bash
sudo systemctl status skirnir-reconcile.timer
sudo systemctl list-timers --all | grep skirnir-reconcile
sudo systemctl status skirnir-reconcile.service
```

Check recent reconcile logs:

```bash
sudo journalctl -u skirnir-reconcile.service -n 200 --no-pager
```

Check containers:

```bash
docker ps
```

## 5) Ongoing operation model

The host applies Git changes automatically:

- Timer runs after boot and every 5 minutes.
- Service runs `clusters/skirnir/scripts/reconcile.sh` as `gitops`.
- Reconcile fetches `origin/main`, resets local checkout, validates compose files, pulls images, and applies stacks.
- Reconcile merges missing keys from `mimir.env.example` into `.env` without overwriting existing values.

## 6) Manual deploy / forced reconcile

Run the same deploy path manually:

```bash
cd /opt/homelab
sudo -u gitops REPO_DIR=/opt/homelab bash clusters/skirnir/scripts/deploy.sh
```

Or run reconcile directly:

```bash
cd /opt/homelab
sudo -u gitops REPO_DIR=/opt/homelab bash clusters/skirnir/scripts/reconcile.sh
```

Run a full app healthcheck:

```bash
cd /opt/homelab
sudo -u gitops REPO_DIR=/opt/homelab bash clusters/skirnir/scripts/healthcheck.sh
```

Run a client-side PowerShell healthcheck (for example from Windows):

```powershell
pwsh -File .\clusters\skirnir\scripts\healthcheck-client.ps1 -Domain aegirshus -Scheme http
```

If using internal HTTPS certs that are not trusted yet:

```powershell
pwsh -File .\clusters\skirnir\scripts\healthcheck-client.ps1 -Domain aegirshus -Scheme https -IgnoreTlsErrors
```

## 7) Changing environment values safely

- Treat `clusters/skirnir/mimir.env.example` as schema/default template.
- Real runtime values live in `clusters/skirnir/.env` on the host.
- Do not commit production `.env` or secret values.
- New keys added to `mimir.env.example` are auto-added to `.env` during reconcile if missing.

## 8) Troubleshooting

### Reconcile fails immediately

Check:

- Repo path exists and is a git work tree.
- `.env` and `mimir.env.example` exist under `clusters/skirnir/`.
- Docker is running.

Commands:

```bash
sudo systemctl status docker
sudo journalctl -u skirnir-reconcile.service -n 200 --no-pager
```

### Permission issues with Docker or files

Check:

- `gitops` user exists.
- `gitops` is in `docker` group.
- `/opt/homelab` and `/srv` ownership/permissions are correct.

Commands:

```bash
id gitops
getent group docker
ls -ld /opt/homelab /srv
```

### Service can’t find repo after moving it

Update service environment and reload:

```bash
sudo systemctl edit skirnir-reconcile.service
# Add/override:
# [Service]
# Environment=REPO_DIR=/new/path/to/homelab

sudo systemctl daemon-reload
sudo systemctl restart skirnir-reconcile.timer
sudo systemctl start skirnir-reconcile.service
```

## 9) Security recommendations

- Enable GitHub Secret Scanning + Push Protection.
- Use templates (`*.env.example`) in Git only.
- Keep real secrets only in host `.env` / secret manager.
- Rotate any secret immediately if ever exposed.
