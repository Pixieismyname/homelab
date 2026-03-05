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
cd homelab
sudo bash clusters/skirnir/scripts/first-run.sh
```

The first-run script performs prechecks, asks for missing config values,
generates required secrets, then runs:

1) `bootstrap-user.sh`
2) `bootstrap.sh`
3) `deploy.sh`
