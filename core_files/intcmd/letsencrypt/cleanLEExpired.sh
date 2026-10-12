#!/usr/bin/env bash
# Deletes expired Let's Encrypt certificates and validates the renewal config of the rest.
# Usage: cleanLEExpired            delete expired, unreferenced certs; report renewal problems
#        cleanLEExpired --dry-run  only report
#        cleanLEExpired --check    print one token per problem on certs that enabled sites use
#                                  (expired-cert:<name>, broken-renewal:<name>), exit 1 if any; used by health_check

SSL_DIR="/web/ssl"
SITES_ENABLED="/web/config/sites-enabled"
MODE="${1:-run}"

# Prints why the renewal config for $1 is unusable, or nothing if it is fine.
renewal_problem() {
    local conf="$SSL_DIR/renewal/$1.conf" key val
    [ -f "$conf" ] || { echo "renewal/$1.conf is missing (certbot will never renew it)"; return; }
    for key in archive_dir cert privkey chain fullchain; do
        val="$(sed -n "s/^${key} *= *//p" "$conf" | head -n1)"
        [ -n "$val" ] || { echo "renewal/$1.conf has no '${key} =' entry"; return; }
        [ -e "$val" ] || { echo "renewal/$1.conf: ${key} points to missing path ${val}"; return; }
    done
    [ -e "$SSL_DIR/live/$1/privkey.pem" ] || { echo "live/$1/privkey.pem is a dangling link"; return; }
}

in_use() { grep -rqs "live/$1/" "$SITES_ENABLED"; }

removed=0
problems=0
for dir in "$SSL_DIR"/live/*/; do
    [ -f "$dir/cert.pem" ] || continue
    name="$(basename "$dir")"

    if openssl x509 -checkend 0 -noout -in "$dir/cert.pem" >/dev/null 2>&1; then
        # Still valid: make sure it can actually be renewed.
        reason="$(renewal_problem "$name")"
        [ -n "$reason" ] || continue
        if [ "$MODE" = "--check" ]; then
            in_use "$name" && { echo "broken-renewal:${name}"; problems=$((problems + 1)); }
        else
            echo "[WARN] ${name}: ${reason}. Re-issue with: createLECert ${name}"
        fi
        continue
    fi

    expired_on="$(openssl x509 -enddate -noout -in "$dir/cert.pem" | cut -d= -f2)"
    if in_use "$name"; then
        problems=$((problems + 1))
        if [ "$MODE" = "--check" ]; then
            echo "expired-cert:${name}"
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
    [ "$problems" -eq 0 ]
    exit
fi
echo "[INFO] Removed ${removed} expired certificate(s)."
