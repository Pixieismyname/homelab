# Shared conventions

Common patterns used by stacks under `clusters/skirnir/apps/*`.

## Networks

- `proxy` network: services that should be reachable via reverse proxy join this network.
- `default` network: stack-internal only.

## Env files

Each stack may include `.env.example` (committed) and expects a real `.env` on the host (not committed).

## Naming

Prefer stable container names and stable volume mount paths.
