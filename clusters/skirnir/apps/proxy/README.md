# proxy (Caddy)

Reverse proxy for homelab services.

## Purpose

Routes hostnames under `${DOMAIN}` to containers on the shared `${PROXY_NETWORK}` Docker network.

Active hostnames include:

- `${DNS_HOST}`
- `${HOMEPAGE_HOST}`
- `${PORTAINER_HOST}`
- `${JELLYFIN_HOST}`
- `${PAPERLESS_HOST}`
- `${HOMEASSISTANT_HOST}`
- `${PROWLARR_HOST}`
- `${SONARR_HOST}`
- `${RADARR_HOST}`
- `${BAZARR_HOST}`
- `${QBITTORRENT_HOST}`

Planned (when stack exists):

- `${WAZUH_HOST}`

## Ports

- 80/tcp exposed on host (LAN HTTP)

## Storage

- `${DOCKER_DATA}/proxy/caddyfile` -> `/etc/caddy/Caddyfile` (read-only)
- `${DOCKER_DATA}/proxy/data` -> `/data`
- `${DOCKER_DATA}/proxy/config` -> `/config`

## Notes

- Uses `host.docker.internal:host-gateway` mapping for host-network service proxying
  (for Home Assistant).
- All target services must:
  1) join the external Docker network `${PROXY_NETWORK}`
  2) have stable container names matching the `Caddyfile` upstreams

## HTTPS on LAN (Caddy internal CA)

This is the easiest way to add SSL/TLS for all web interfaces on a private LAN.

### How it works

- Caddy issues certificates from its own internal certificate authority (`tls internal`).
- Certificates are valid for your internal hostnames (for example `home.${DOMAIN}`).
- Browsers trust them after you install Caddy's internal root CA on your devices.

### Prerequisites

- DNS for your service hostnames already resolves to Skirnir's LAN IP.
- Proxy stack uses persisted Caddy data volume (`${DOCKER_DATA}/proxy/data`).
- You can modify:
  - `apps/proxy/compose.yaml`
  - `apps/proxy/Caddyfile`

### Step 1: expose HTTPS port on Caddy

In `apps/proxy/compose.yaml`, under `ports`, enable:

- `443:443`

You can keep `80:80` for cleartext access and redirects.

### Step 2: enable TLS in Caddyfile

Update each site block from `http://...` to hostname-only (or `https://...`) and add:

- `tls internal`

Example:

```caddy
{$HOMEPAGE_HOST} {
  tls internal
  reverse_proxy homepage:3000
}
```

Do this for each LAN UI route you want on HTTPS.

### Step 3: optional HTTP to HTTPS redirect

If you keep port 80 open, add an explicit redirect site block for each hostname or a global strategy so users are pushed to HTTPS.

### Step 4: deploy changes

Run reconcile/deploy after commit:

```bash
cd /opt/homelab
clusters/skirnir/scripts/reconcile.sh
```

### Step 5: trust Caddy root CA on clients

Caddy stores the internal CA root certificate in the data volume, typically at:

- `/data/caddy/pki/authorities/local/root.crt` (inside container)

Because `/data` is persisted from `${DOCKER_DATA}/proxy/data`, the host path is typically:

- `${DOCKER_DATA}/proxy/data/caddy/pki/authorities/local/root.crt`

#### 5a) Export/copy certificate from server

From the server, confirm the certificate exists:

```bash
sudo ls -l ${DOCKER_DATA}/proxy/data/caddy/pki/authorities/local/root.crt
```

Copy it to your client (example using SCP from your Windows machine):

```bash
scp <user>@<skirnir-ip>:${DOCKER_DATA}/proxy/data/caddy/pki/authorities/local/root.crt .
```

You can keep the filename as `root.crt` or rename to `caddy-local-root.crt`.

#### 5b) Trust on Windows (system-wide)

1. Copy `root.crt` to the Windows machine.
2. Open `certlm.msc` (Local Computer certificates).
3. Go to **Trusted Root Certification Authorities** -> **Certificates**.
4. Right-click -> **All Tasks** -> **Import...**.
5. Select `root.crt`, place it in **Trusted Root Certification Authorities**, finish import.
6. Restart browsers that were open during import.

PowerShell alternative (run as Administrator):

```powershell
Import-Certificate -FilePath .\root.crt -CertStoreLocation Cert:\LocalMachine\Root
```

#### 5c) Trust on Android

1. Copy `root.crt` to the phone.
2. Open **Settings** -> **Security** -> **Encryption & credentials** -> **Install a certificate**.
3. Choose **CA certificate**.
4. Select `root.crt` and confirm installation.

Notes for Android:

- Certificate menu paths vary by vendor/version.
- Some apps only trust system CAs and may ignore user-installed CAs.
- Browsers usually honor user-installed CAs.

Install that root certificate in the OS/browser trust store on each client device.

After trust is installed, HTTPS cert warnings disappear for internal hostnames.

### Verification checklist

- `https://home.${DOMAIN}` loads successfully.
- Browser cert issuer is Caddy local authority.
- No certificate warning after trust installation.
- Caddy logs show successful TLS handshakes.

### Troubleshooting

- **Certificate warning remains**
  - Root CA is not installed (or not installed in the correct trust store) on that client.
- **Hostname mismatch**
  - Client URL does not match cert SAN; verify URL and Caddy site address.
- **Connection refused on 443**
  - Ensure `443:443` is exposed and host firewall allows 443/tcp.
- **Route works on HTTP but not HTTPS**
  - Confirm block uses hostname/HTTPS address and includes `tls internal`.

### Rollback

If needed, revert to HTTP-only by:

- Removing `tls internal` from site blocks
- Switching addresses back to `http://...`
- Removing `443:443` from compose ports
