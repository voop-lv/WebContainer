#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Installing apache2"
apt-get update
apt-get install -y --no-install-recommends apache2
apache2 -v

echo "[INFO] Enabling/disabling modules"
a2enmod -q headers ssl http2 proxy proxy_http proxy_fcgi macro
# Directory listings and the /server-status page are off.
a2dismod -q -f autoindex status
# Debian's http2.conf sets "Protocols h2 h2c http/1.1" server-wide (a later Protocols line does not override it),
# which offers "Upgrade: h2,h2c" on every plain-HTTP response. HTTPS sites enable h2 themselves.
rm -f /etc/apache2/mods-enabled/http2.conf

echo "[INFO] Building /config/apache2 from the package layout plus the shipped config"
# Keep the package's modules, envvars, magic and ports.conf; apache2.conf and snippets come from this image.
# Debian's conf-*/sites-* dirs are not included by the shipped apache2.conf (sites live in /web/config).
cp -a -n /etc/apache2/. /temp_config/apache2/
rm -rf /temp_config/apache2/conf-available /temp_config/apache2/conf-enabled \
       /temp_config/apache2/sites-available /temp_config/apache2/sites-enabled

echo "[INFO] Rendering per-PHP-version fastcgi includes"
for v in $(cat /vl/php_versions); do
    sed "s/{PHP_VERSION}/${v}/g; s/{PHP_VERSION_NODOT}/${v//./}/g" /temp_config/apache2/snippets/php_fastcgi.conf > "/temp_config/apache2/snippets/php${v//./}_fastcgi.conf"
done
rm /temp_config/apache2/snippets/php_fastcgi.conf

echo "[INFO] Landing page logo"
mkdir -p /temp_config/defaults/page/webdata/img
cp /usr/share/apache2/icons/apache_pb.svg /temp_config/defaults/page/webdata/img/apache.svg

echo "[INFO] Validating shipped config and default site"
# apache2.conf includes /web/config/sites-enabled/*.conf; stage the default site there so it is checked too.
mkdir -p /web/config/sites-enabled
cp /temp_config/defaults/page/default.conf /web/config/sites-enabled/
bash -c '. /etc/apache2/envvars && mkdir -p "$APACHE_RUN_DIR" && apache2 -d /temp_config/apache2 -t'
rm -rf /web

echo "[INFO] Installing supervisor pack config"
cp -f /temp_config/supervisord/1_pack.conf /vl/supervisord/1_pack.conf
rm -rf /temp_config/supervisord

echo "[INFO] Updating clean install dir and config dir"
# -a keeps the relative mods-enabled -> mods-available symlinks.
cp -a -f /temp_config/. /clean/config/
cp -a -f /temp_config/. /config/

apt-get clean
rm -rf /var/lib/apt/lists/*
echo "=== End of script ==="
