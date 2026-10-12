#!/usr/bin/env bash
set -euo pipefail

CLEAN_PATH="/clean"
SCRIPTS_PATH="/scripts"
CONFIG_PATH="/config"
PHP_ROOT="/etc/php"

echo "[INFO] Applying PHP hardening overlay"
for v in $(cat /vl/php_versions); do
    cat > "${PHP_ROOT}/${v}/fpm/conf.d/99-hardening.ini" <<'INI'
; Shipped by the webcontainer image. Override per pool with php_admin_value[...] in the pool config.
expose_php = Off
display_errors = Off
display_startup_errors = Off
log_errors = On
allow_url_include = Off
cgi.fix_pathinfo = 0
session.use_strict_mode = 1
session.cookie_httponly = 1
session.cookie_samesite = Lax
; Shell-out and dynamic loading are off for web requests (CLI is unaffected).
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,pcntl_exec,pcntl_fork,dl
; Sites live under /web; sessions and bundled PEAR code need to stay reachable.
open_basedir = /web/:/tmp/:/var/lib/php/:/usr/share/php/
INI
done

echo "[INFO] Creating clean directory"
mkdir -p "${CLEAN_PATH}/scripts" "${CLEAN_PATH}/config/php"
cp -r -f "${SCRIPTS_PATH}"/* "${CLEAN_PATH}/scripts"
cp -r -f "${CONFIG_PATH}"/* "${CLEAN_PATH}/config"
cp -r -f "${PHP_ROOT}"/* "${CLEAN_PATH}/config/php"

chmod 755 -R "${CLEAN_PATH}/scripts"
echo "[INFO] The operation finished successfully!"
