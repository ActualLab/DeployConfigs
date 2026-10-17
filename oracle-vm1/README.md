# oracle-vm1

Shared configuration for the Oracle Cloud A1 VM (hostname `vnic-primary`) that
hosts several ActualLab sample apps behind Cloudflare. Its origin IP is not
published here — the sites are reached via their Cloudflare-proxied hostnames.

## What runs here

| Subdomain | App container | App repo |
|---|---|---|
| `boardgames.actuallab.net` | `boardgames-app` | ActualLab/BoardGames |
| `todoapp.actuallab.net` | `todoapp-app` | ActualLab/Fusion.Samples |
| `blazor-samples.actuallab.net` | `blazor-app` | ActualLab/Fusion.Samples |
| `townhall.actuallab.net` | `townhall-app` | ActualLab/Fusion.TownHall |
| `fusion.actuallab.net` | `fusion-app` | ActualLab/Fusion (docs + MCP) |
| `docs.voxt.ai` (DNS not on Cloudflare; ACME cert) | `docs-app` | Actual-Chat/docs (private), deployed from [`docs/`](docs/) |

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

## Voxt documentation (`docs/`)

The docs repo is private; it builds its own image (`mcp-server/Dockerfile`: the site
at `/`, the documentation MCP server at `/mcp`), and its compose file, deploy script
and timer live here. The VM clones it over SSH with a read-only deploy key:

```bash
ssh-keygen -t ed25519 -N '' -C oracle-vm1-docs -f ~/.ssh/docs_deploy  # add the .pub as a deploy key on Actual-Chat/docs
cat >> ~/.ssh/config <<'EOF'
Host github-docs
  HostName github.com
  User git
  IdentityFile ~/.ssh/docs_deploy
  IdentitiesOnly yes
EOF
sudo apt-get install -y git-lfs && git lfs install --skip-repo
git clone git@github-docs:actual-chat/docs.git /opt/apps/docs  # full clone: the build needs the history
sudo cp docs/systemd/docs-deploy.* /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now docs-deploy.timer
```

`docs/deploy.sh` redeploys when the docs branch moves, or when
`docs/docker-compose.prod.yml` changes.

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
