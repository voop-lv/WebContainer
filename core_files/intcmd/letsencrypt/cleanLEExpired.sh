#!/usr/bin/env bash
# Deletes Let's Encrypt certificates that have expired and are no longer referenced by an enabled site.
# Usage: cleanLEExpired            delete expired, unreferenced certs
#        cleanLEExpired --dry-run  only report what would be deleted
#        cleanLEExpired --check    print expired certs still referenced by a site, exit 1 if any (used by health_check)

SSL_DIR="/web/ssl"
SITES_ENABLED="/web/config/sites-enabled"
MODE="${1:-run}"

removed=0
in_use=0
for dir in "$SSL_DIR"/live/*/; do
    [ -f "$dir/cert.pem" ] || continue
    name="$(basename "$dir")"
    if openssl x509 -checkend 0 -noout -in "$dir/cert.pem" >/dev/null 2>&1; then
        continue
    fi
    expired_on="$(openssl x509 -enddate -noout -in "$dir/cert.pem" | cut -d= -f2)"
    if grep -rqs "live/${name}/" "$SITES_ENABLED"; then
        in_use=$((in_use + 1))
        if [ "$MODE" = "--check" ]; then
            echo "$name"
        else
            echo "[WARN] ${name} expired on ${expired_on} but is still referenced in ${SITES_ENABLED}; keeping it (fix renewal or remove the site first)"
        fi
        continue
    fi
    [ "$MODE" = "--check" ] && continue
    echo "[INFO] ${name} expired on ${expired_on}"
    if [ "$MODE" = "--dry-run" ]; then
        echo "[DRY-RUN] would delete ${name}"
        continue
    fi
    if [ -f "$SSL_DIR/renewal/${name}.conf" ]; then
        if certbot delete --config-dir "$SSL_DIR" --cert-name "$name" --non-interactive; then
            removed=$((removed + 1))
        else
            echo "[ERROR] certbot failed to delete ${name}"
        fi
    else
        # No renewal config: certbot refuses to touch it, so remove the orphaned live/ and archive/ dirs ourselves.
        echo "[INFO] ${name} has no renewal config (orphan); removing ${SSL_DIR}/live/${name} and ${SSL_DIR}/archive/${name}"
        rm -rf "${SSL_DIR}/live/${name}" "${SSL_DIR}/archive/${name}"
        removed=$((removed + 1))
    fi
done

if [ "$MODE" = "--check" ]; then
    [ "$in_use" -eq 0 ]
    exit
fi
echo "[INFO] Removed ${removed} expired certificate(s)."
