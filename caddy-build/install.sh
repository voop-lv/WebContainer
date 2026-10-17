#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Adding official Caddy stable repository"
apt-get update
curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt > /etc/apt/sources.list.d/caddy-stable.list
chmod 644 /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list

echo "[INFO] Installing caddy"
apt-get update
apt-get install -y --no-install-recommends caddy
caddy version

echo "[INFO] Rendering per-PHP-version fastcgi snippets"
for v in $(cat /vl/php_versions); do
    sed "s/{PHP_VERSION}/${v}/g; s/{PHP_VERSION_NODOT}/${v//./}/g" /temp_config/caddy/snippets/php_fastcgi.conf > "/temp_config/caddy/snippets/php${v//./}_fastcgi.conf"
done
rm /temp_config/caddy/snippets/php_fastcgi.conf

echo "[INFO] Validating shipped Caddyfile and default site"
# The Caddyfile imports /web/config/sites-enabled/*.conf; stage the default site there so it is checked too.
mkdir -p /web/config/sites-enabled
cp /temp_config/defaults/page/default.conf /web/config/sites-enabled/
caddy validate --config /temp_config/caddy/Caddyfile
rm -rf /web

# Access logs from the `log` directive (see sites.example.conf) go here.
mkdir -p /var/log/caddy

echo "[INFO] Installing supervisor pack config"
cp -f /temp_config/supervisord/1_pack.conf /vl/supervisord/1_pack.conf
rm -rf /temp_config/supervisord

echo "[INFO] Updating clean install dir and config dir"
cp -r -f /temp_config/* /clean/config
cp -r -f /temp_config/* /config/

apt-get clean
rm -rf /var/lib/apt/lists/*
echo "=== End of script ==="
