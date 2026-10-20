#!/usr/bin/env bash
# One-shot at container start. Web data belongs to www-data; nothing is world-writable.
# /web/ssl and /web/caddy are skipped on purpose: certbot and Caddy keep their private keys root-only.
set -u

fix() {
    echo "[INFO] Fixing ownership/permissions for $1"
    chown -R www-data:www-data "$1"
    chmod -R u=rwX,g=rX,o=rX "$1"
}

[ -d /run/php ] && fix /run/php
for path in /web/*; do
    [ -d "$path" ] || continue
    [ "$path" = "/web/ssl" ] && continue
    [ "$path" = "/web/caddy" ] && continue
    fix "$path"
done
echo "[INFO] Permission fix completed."
