# Docker networking model

## proxy network
A single shared Docker network named `proxy` is used for all web apps that should be routed by the reverse proxy.

- The reverse proxy container attaches to `proxy`.
- Each web app attaches to `proxy`.
- Routing is done by hostname (e.g. `jellyfin.aegirshus`) to the right container.

This avoids exposing lots of ports on the host.