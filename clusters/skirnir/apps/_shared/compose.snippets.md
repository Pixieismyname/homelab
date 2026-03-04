# Compose snippets

## External proxy network

Add to each stack that should be reachable through the reverse proxy:

```yaml
networks:
  proxy:
    external: true
    name: proxy

services:
  myservice:
    networks:
      - proxy
      - default


(Yes, it’s markdown, not YAML — it’s a snippet library for humans. Keeps things consistent.)

---

# 4) Commit

```bash
git add .
git commit -m "Define shared proxy network bootstrap and documentation"
git push