# Skirnir bootstrap (Ubuntu 24.04 LTS)

## Install media
- Ubuntu Server 24.04 LTS
- During install:
  - enable OpenSSH server
  - set hostname: skirnir
  - create your admin user
  - (optional) static DHCP lease in router later

## After first boot
Clone the homelab repo and run:

```bash
cd homelab/clusters/skirnir/bootstrap
sudo bash bootstrap.sh