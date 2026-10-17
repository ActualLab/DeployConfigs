#!/usr/bin/env bash
# Poll-based auto-deploy for the Voxt documentation. Invoked by docs-deploy.timer,
# but can also be run by hand. Redeploys when the docs branch moves, or when this
# folder's Dockerfile/compose file changes (edge-deploy.timer pulls those).
# A failed build leaves the previous container serving and is not retried until
# the next change or --force, so a broken commit doesn't rebuild every minute.
set -euo pipefail

REPO_DIR="${REPO_DIR:-/opt/apps/docs}"
BRANCH="${BRANCH:-master}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$HERE/docker-compose.prod.yml"
STAMP_FILE="$REPO_DIR/.git/deployed-stamp"
FAILED_FILE="$REPO_DIR/.git/failed-stamp"

cd "$REPO_DIR"

git fetch --quiet origin "$BRANCH"
REMOTE="$(git rev-parse "origin/$BRANCH")"
STAMP="$REMOTE $(cat "$HERE/Dockerfile" "$COMPOSE_FILE" | sha1sum | cut -d' ' -f1)"

if [[ "${1:-}" != "--force" ]]; then
    [[ "$(cat "$STAMP_FILE" 2>/dev/null)" == "$STAMP" ]] && exit 0
    [[ "$(cat "$FAILED_FILE" 2>/dev/null)" == "$STAMP" ]] && exit 0
fi

echo "$(date -u +%FT%TZ) Deploying $REMOTE (was $(git rev-parse HEAD))"
git reset --hard "origin/$BRANCH"
git lfs pull
if ! docker compose -f "$COMPOSE_FILE" up -d --build; then
    echo "$STAMP" > "$FAILED_FILE"
    echo "$(date -u +%FT%TZ) Deploy FAILED; the previous build keeps serving." \
        "Retried on the next change, or run with --force." >&2
    exit 1
fi
echo "$STAMP" > "$STAMP_FILE"
rm -f "$FAILED_FILE"
docker image prune -f >/dev/null 2>&1 || true
echo "$(date -u +%FT%TZ) Deploy complete"
