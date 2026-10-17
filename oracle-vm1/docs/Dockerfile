# syntax=docker/dockerfile:1
# Static build of the Voxt documentation (Actual-Chat/docs, VitePress), served by
# Caddy on :8080 for the shared edge proxy. The build context is the docs clone
# (/opt/apps/docs), not this repo; it includes .git on purpose — the build's
# docs:versions:check and VitePress lastUpdated both need the full history.

FROM node:22-bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN git config --global --add safe.directory /src && npm run app:build

FROM caddy:2-alpine
COPY --from=build /src/.vitepress/dist /srv
COPY <<'CADDY' /etc/caddy/Caddyfile
:8080 {
	root * /srv
	encode zstd gzip
	header /assets/* Cache-Control "public, max-age=31536000, immutable"
	# VitePress cleanUrls: /users/foo is served from /users/foo.html
	try_files {path} {path}.html {path}/index.html
	file_server
	handle_errors {
		rewrite * /404.html
		file_server
	}
}
CADDY
