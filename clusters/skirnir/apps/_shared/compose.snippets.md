# Compose snippets

## External proxy network

Add this to each stack that should be reachable through the reverse proxy:

```yaml
networks:
  proxy:
    external: true
    name: ${PROXY_NETWORK}

services:
  myservice:
    networks:
      - proxy
      - default
```

This file is a human reference (not a Compose file).
