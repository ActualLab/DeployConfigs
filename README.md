# ActualLab.DeployConfigs

Shared, host-level deployment configuration for the machines that host ActualLab
sample apps. Each VM gets its own top-level folder holding the configs that are
**shared across all apps on that host** — primarily the edge reverse proxy that
owns ports 80/443 and terminates TLS.

Per-app deployment (each app's own `Dockerfile`, `deploy/docker-compose.prod.yml`,
systemd timer) still lives in that app's own repository. Only the shared,
cross-app pieces live here.

## Hosts

- [`oracle-vm1/`](oracle-vm1/) — the Oracle Cloud A1 VM (`161.153.30.140`,
  `fusion.actuallab.net` + the BoardGames / TownHall / Fusion.Samples subdomains).

## Deploy model

Same poll-based model as the apps: the repo is cloned to `/opt/apps/deploy-configs`
on the host, and a systemd timer polls `origin/main` and re-applies the shared
stack(s) when it moves. Secrets (TLS origin cert/key, `.env`) are host-managed and
git-ignored — they are never committed.
