# Docker bootstrap (skirnir)

This folder contains one-time Docker bootstrap artifacts.

## Shared proxy network

We use a shared Docker network named `proxy` so that a reverse proxy (Caddy) can reach
all web apps across multiple compose stacks.

- The network is created once using `compose.network.yaml`.
- Each stack references it as an external network.

This avoids recreating networks per stack and keeps cross-stack routing stable.
