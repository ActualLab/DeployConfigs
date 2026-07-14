#!/usr/bin/env bash
# Poll-based auto-deploy for the oracle-vm1 shared edge proxy. Invoked by
# edge-deploy.timer, but can also be run by hand. No-op when the tracked branch
# has not moved.
set -euo pipefail

REPO_DIR="${REPO_DIR:-/opt/apps/deploy-configs}"
BRANCH="${BRANCH:-main}"
COMPOSE_FILE="oracle-vm1/edge/docker-compose.prod.yml"
CADDYFILE="oracle-vm1/edge/Caddyfile"

cd "$REPO_DIR"

git fetch --quiet origin "$BRANCH"
LOCAL="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse "origin/$BRANCH")"

if [[ "$LOCAL" == "$REMOTE" && "${1:-}" != "--force" ]]; then
    exit 0
fi

echo "$(date -u +%FT%TZ) Deploying $REMOTE (was $LOCAL)"
before="$(sha1sum "$CADDYFILE" 2>/dev/null | cut -d' ' -f1)"
git reset --hard "origin/$BRANCH"
after="$(sha1sum "$CADDYFILE" 2>/dev/null | cut -d' ' -f1)"

docker compose -f "$COMPOSE_FILE" up -d
# The Caddyfile is bind-mounted as a file; git replaces it via rename (new inode),
# so the running container keeps the stale one. When it changes, recreate Caddy so
# it re-binds the current file.
if [[ "$before" != "$after" ]]; then
    docker compose -f "$COMPOSE_FILE" up -d --force-recreate edge-caddy
fi
docker image prune -f >/dev/null 2>&1 || true
echo "$(date -u +%FT%TZ) Deploy complete"
