#!/usr/bin/env bash
set -Eeuo pipefail

LOCK_FILE="/tmp/lazymount.lock"

if [[ -f "$LOCK_FILE" ]]; then
    echo "[ERROR] Lazy mount already executed. (This is only supposed to run once at container start)"
    exit 1
fi
touch "$LOCK_FILE"

declare -A MOUNTS
MOUNTS["/etc/php"]="/config/php"
if [ -d "/usr/local/openresty" ]; then
    MOUNTS["/usr/local/openresty/nginx/conf"]="/config/openresty"
elif [ -x "/usr/sbin/nginx" ]; then
    MOUNTS["/etc/nginx"]="/config/nginx"
fi

for to_path in "${!MOUNTS[@]}"; do
    from_path="${MOUNTS[${to_path}]}"
    echo "From Path: ${from_path} To Path: ${to_path}"
    rm -rf "${to_path}"
    mkdir -vp "${from_path}" "$(dirname "${to_path}")"
    # Config is read by root (nginx/php-fpm masters); it must not be writable by www-data.
    chown -R root:root "${from_path}"
    chmod -R u=rwX,go=rX "${from_path}"
    ln -sT "${from_path}" "${to_path}"
    echo "Mounted $(basename "${from_path}")"
done
