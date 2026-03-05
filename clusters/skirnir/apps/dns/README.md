# dns (AdGuard Home)

Local DNS for the `aegirshus` zone, running on Skirnir.

## Goals

- Network-wide DNS on port 53 (TCP/UDP)
- Admin UI behind the reverse proxy (Caddy)

## Ports

- `53/tcp` on host
- `53/udp` on host

## Storage

- `${DOCKER_DATA}/dns/work` -> `/opt/adguardhome/work`
- `${DOCKER_DATA}/dns/conf` -> `/opt/adguardhome/conf`

## Network

- Joins external `${PROXY_NETWORK}` network for proxy reachability

## Access

After the proxy route is added, the UI will be reachable at:

- `http://dns.${DOMAIN}`

## First-time setup notes

When you go through the AdGuard setup wizard, configure:

- Web UI port: **3000** (recommended to avoid conflicts)
- Bind address: `0.0.0.0`

Caddy will proxy `dns.${DOMAIN}` to `adguard:3000`.

## Router setting (later)

Set your router/DHCP DNS server to Skirnir’s LAN IP so clients use AdGuard.
