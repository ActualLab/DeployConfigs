# oracle-vm1

Shared configuration for the Oracle Cloud A1 VM (`161.153.30.140`, hostname
`vnic-primary`) that hosts several ActualLab sample apps behind Cloudflare.

## What runs here

| Subdomain | App container | App repo |
|---|---|---|
| `boardgames.actuallab.net` | `boardgames-app` | ActualLab/BoardGames |
| `todoapp.actuallab.net` | `todoapp-app` | ActualLab/Fusion.Samples |
| `blazor-samples.actuallab.net` | `blazor-app` | ActualLab/Fusion.Samples |
| `townhall.actuallab.net` | `townhall-app` | ActualLab/Fusion.TownHall |
| `fusion.actuallab.net` | `fusion-app` | ActualLab/Fusion (docs + MCP) |

All app containers publish no ports; they join the shared external **`edge`**
network and are reached by container name. The only thing that owns ports 80/443
is [`edge/`](edge/) — the shared Caddy reverse proxy defined here.

## Topology

```
Browser ─HTTPS─> Cloudflare (proxied, Full TLS) ─HTTPS─> edge-caddy :443 ─HTTP─> <app>-app :8080
```

`edge-caddy` terminates TLS with the Cloudflare wildcard Origin cert
(`*.actuallab.net`, host-managed in `edge/certs/`), so adding a subdomain needs no
new certificate — only a Caddyfile block plus a Cloudflare DNS record.

## First-time host setup

```bash
git clone https://github.com/ActualLab/DeployConfigs /opt/apps/deploy-configs
docker network create edge            # the shared edge network
# place the origin cert/key (host-managed, git-ignored):
#   /opt/apps/deploy-configs/oracle-vm1/edge/certs/origin.pem
#   /opt/apps/deploy-configs/oracle-vm1/edge/certs/origin.key   (chmod 600)
cd /opt/apps/deploy-configs/oracle-vm1/edge
docker compose -f docker-compose.prod.yml up -d
```

Then each app stack (in its own repo) joins the `edge` network and is routed by
the Caddyfile here.

## Auto-deploy

```bash
sudo cp edge/systemd/edge-deploy.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now edge-deploy.timer
```

The timer polls `origin/main` every minute and re-applies the edge stack
(recreating `edge-caddy` when the Caddyfile changes). Force now:
`edge/deploy.sh --force`.

## Migrating the edge out of BoardGames (one-time)

Historically the edge Caddy lived in the BoardGames stack and the shared network
was `boardgames_default`. To move to this repo with the neutral `edge` network,
with a short (~1 min) routing outage:

```bash
docker network create edge
# 1) Repoint each app stack onto `edge` (updated compose in each app repo):
for d in boardgames fusion-samples townhall fusion; do
  ( cd /opt/apps/$d/deploy && docker compose -f docker-compose.prod.yml up -d )
done
# 2) Stop the old edge Caddy owned by BoardGames, then start the shared one:
docker rm -f boardgames-caddy-1
cd /opt/apps/deploy-configs/oracle-vm1/edge && docker compose -f docker-compose.prod.yml up -d
```
