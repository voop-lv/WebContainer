#!/usr/bin/env bash
set -euo pipefail

# Modules on in /etc/apache2/mods-enabled: Debian's defaults minus autoindex/status, plus what the snippets use.
ENABLED_MODS="mpm_event access_compat alias auth_basic authn_core authn_file authz_core authz_host authz_user
    deflate dir env filter mime negotiation reqtimeout setenvif headers ssl http2 proxy proxy_http proxy_fcgi
    macro socache_shmcb"

echo "[INFO] Installing apache2"
apk add --no-cache apache2 apache2-ssl apache2-proxy apache2-http2 apache2-utils apache2-icons mailcap

# The config keeps Debian's layout (apache2.conf, envvars, ports.conf, mods-available/mods-enabled), so existing
# /config/apache2 volumes and the shipped snippets work unchanged on Alpine's httpd:
#  - `apache2` runs httpd with ServerRoot /etc/apache2 and apache2.conf, and loads the modules Debian compiles
#    in (apache2.conf uses User/Group before it includes mods-enabled);
#  - Debian's LoadModule paths (/usr/lib/apache2/modules/mod_*.so) resolve;
#  - Debian's mods-available/ssl.conf names /usr/share/apache2/ask-for-passphrase.
cat > /usr/sbin/apache2 <<'EOF'
#!/bin/sh
# Debian-style apache2 on Alpine's httpd (see apache-build/install.sh). A later -d overrides /etc/apache2.
exec /usr/sbin/httpd -d /etc/apache2 -f apache2.conf \
    -C 'LoadModule unixd_module /usr/lib/apache2/mod_unixd.so' \
    -C 'LoadModule log_config_module /usr/lib/apache2/mod_log_config.so' \
    -C 'LoadModule logio_module /usr/lib/apache2/mod_logio.so' \
    -C 'LoadModule version_module /usr/lib/apache2/mod_version.so' \
    -C 'LoadModule watchdog_module /usr/lib/apache2/mod_watchdog.so' \
    "$@"
EOF
chmod 755 /usr/sbin/apache2
ln -s . /usr/lib/apache2/modules
printf '#!/bin/sh\necho "[ERROR] encrypted TLS private keys are not supported: no passphrase prompt in the container" >&2\nexit 1\n' \
    > /usr/share/apache2/ask-for-passphrase
chmod 755 /usr/share/apache2/ask-for-passphrase
apache2 -v

echo "[INFO] Building /config/apache2: shipped config plus a .load file for every installed module"
mkdir -p /temp_config/apache2/mods-available /temp_config/apache2/mods-enabled
for so in /usr/lib/apache2/mod_*.so; do
    m="$(basename "${so}" .so)"
    m="${m#mod_}"
    echo "LoadModule ${m}_module /usr/lib/apache2/modules/mod_${m}.so" > "/temp_config/apache2/mods-available/${m}.load"
done
for m in ${ENABLED_MODS}; do
    [ -f "/temp_config/apache2/mods-available/${m}.load" ] || { echo "[ERROR] apache module ${m} is not installed"; exit 1; }
    for f in "${m}.load" "${m}.conf"; do
        [ -f "/temp_config/apache2/mods-available/${f}" ] && ln -s "../mods-available/${f}" "/temp_config/apache2/mods-enabled/${f}"
    done
done
cp /etc/apache2/magic /temp_config/apache2/

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
bash -c '. /temp_config/apache2/envvars && mkdir -p "$APACHE_RUN_DIR" && apache2 -d /temp_config/apache2 -t'
rm -rf /web

echo "[INFO] Installing supervisor pack config"
cp -f /temp_config/supervisord/1_pack.conf /vl/supervisord/1_pack.conf
rm -rf /temp_config/supervisord

echo "[INFO] Updating clean install dir and config dir"
# -a keeps the relative mods-enabled -> mods-available symlinks.
cp -a -f /temp_config/. /clean/config/
cp -a -f /temp_config/. /config/

rm -rf /var/cache/apk/*
echo "=== End of script ==="
