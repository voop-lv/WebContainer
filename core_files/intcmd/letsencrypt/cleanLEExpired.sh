#!/usr/bin/env bash
# Deletes Let's Encrypt certificates that have expired and are no longer referenced by an enabled site.
# Usage: cleanLEExpired [--dry-run]

SSL_DIR="/web/ssl"
SITES_ENABLED="/web/config/sites-enabled"
DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

removed=0
for dir in "$SSL_DIR"/live/*/; do
    [ -f "$dir/cert.pem" ] || continue
    name="$(basename "$dir")"
    if openssl x509 -checkend 0 -noout -in "$dir/cert.pem" >/dev/null 2>&1; then
        continue
    fi
    expired_on="$(openssl x509 -enddate -noout -in "$dir/cert.pem" | cut -d= -f2)"
    if grep -rqs "live/${name}/" "$SITES_ENABLED"; then
        echo "[WARN] ${name} expired on ${expired_on} but is still referenced in ${SITES_ENABLED}; keeping it (fix renewal or remove the site first)"
        continue
    fi
    echo "[INFO] ${name} expired on ${expired_on}"
    if $DRY_RUN; then
        echo "[DRY-RUN] would delete ${name}"
        continue
    fi
    if certbot delete --config-dir "$SSL_DIR" --cert-name "$name" --non-interactive; then
        removed=$((removed + 1))
    else
        echo "[ERROR] certbot failed to delete ${name}"
    fi
done
echo "[INFO] Removed ${removed} expired certificate(s)."
