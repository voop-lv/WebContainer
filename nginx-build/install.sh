#!/usr/bin/env bash
set -euo pipefail

alpine="v$(cut -d. -f1,2 /etc/alpine-release)"
echo "[INFO] Adding official nginx.org stable repository for Alpine ${alpine}"
# apk checks every package from the @nginx repo against this key.
curl -fsSLo /etc/apk/keys/nginx_signing.rsa.pub https://nginx.org/keys/nginx_signing.rsa.pub
echo "@nginx https://nginx.org/packages/alpine/${alpine}/main" >> /etc/apk/repositories

echo "[INFO] Installing nginx"
apk add --no-cache nginx@nginx
nginx -v

# Lowest accepted nginx: the build fails instead of shipping an unpatched one.
# 1.30.6 (2026-10-14) fixes CVE-2026-15176, -93479, -95101, -97205, -97629 and everything before it.
NGINX_MIN="1.30.6"
installed="$(nginx -v 2>&1 | sed -n 's|^nginx version: nginx/||p')"
if [ "$(apk version -t "${installed}" "${NGINX_MIN}")" = "<" ]; then
    echo "[ERROR] nginx ${installed} is older than ${NGINX_MIN} (security floor)"
    exit 1
fi

echo "[INFO] Rendering per-PHP-version fastcgi includes"
for v in $(cat /vl/php_versions); do
    sed "s/{PHP_VERSION}/${v}/g" /temp_config/nginx/php_fastcgi.conf > "/temp_config/nginx/php${v//./}_fastcgi.conf"
done
rm /temp_config/nginx/php_fastcgi.conf

# /etc/nginx gets replaced by a symlink to /config/nginx at runtime (lazymount); keep the package's helper files.
cp -f /etc/nginx/mime.types /etc/nginx/fastcgi_params /temp_config/nginx/

echo "[INFO] Installing supervisor pack config"
cp -f /temp_config/supervisord/1_pack.conf /vl/supervisord/1_pack.conf
rm -rf /temp_config/supervisord

echo "[INFO] Updating clean install dir and config dir"
cp -r -f /temp_config/* /clean/config
cp -r -f /temp_config/* /config/

rm -rf /var/cache/apk/*
echo "=== End of script ==="
