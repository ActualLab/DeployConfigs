#!/usr/bin/env bash
# Poll-based auto-deploy for the Voxt documentation. Invoked by docs-deploy.timer,
# but can also be run by hand. Redeploys when the docs branch moves, or when this
# folder's Dockerfile/compose file changes (edge-deploy.timer pulls those).
set -euo pipefail

REPO_DIR="${REPO_DIR:-/opt/apps/docs}"
BRANCH="${BRANCH:-master}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$HERE/docker-compose.prod.yml"
STAMP_FILE="$REPO_DIR/.git/deployed-stamp"

cd "$REPO_DIR"

git fetch --quiet origin "$BRANCH"
REMOTE="$(git rev-parse "origin/$BRANCH")"
STAMP="$REMOTE $(cat "$HERE/Dockerfile" "$COMPOSE_FILE" | sha1sum | cut -d' ' -f1)"

if [[ "$(cat "$STAMP_FILE" 2>/dev/null)" == "$STAMP" && "${1:-}" != "--force" ]]; then
    exit 0
fi

echo "$(date -u +%FT%TZ) Deploying $REMOTE (was $(git rev-parse HEAD))"
git reset --hard "origin/$BRANCH"
git lfs pull
docker compose -f "$COMPOSE_FILE" up -d --build
echo "$STAMP" > "$STAMP_FILE"
docker image prune -f >/dev/null 2>&1 || true
echo "$(date -u +%FT%TZ) Deploy complete"
