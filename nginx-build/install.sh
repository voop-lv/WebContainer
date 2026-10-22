#!/usr/bin/env bash
set -euo pipefail

. /etc/os-release
echo "[INFO] Adding official nginx.org stable repository"
apt-get update
curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/debian ${VERSION_CODENAME} nginx" > /etc/apt/sources.list.d/nginx.list
printf "Package: *\nPin: origin nginx.org\nPin-Priority: 900\n" > /etc/apt/preferences.d/99nginx

echo "[INFO] Installing nginx"
apt-get update
apt-get install -y --no-install-recommends nginx
nginx -v

# Lowest accepted nginx: the build fails instead of shipping an unpatched one.
# 1.30.6 (2026-10-14) fixes CVE-2026-15176, -93479, -95101, -97205, -97629 and everything before it.
NGINX_MIN="1.30.6"
installed="$(nginx -v 2>&1 | grep -oP 'nginx/\K[0-9.]+')"
if ! dpkg --compare-versions "${installed}" ge "${NGINX_MIN}"; then
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

apt-get clean
rm -rf /var/lib/apt/lists/*
echo "=== End of script ==="
