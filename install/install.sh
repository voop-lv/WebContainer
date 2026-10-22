#!/usr/bin/env bash
set -euo pipefail

# Single source of truth for shipped PHP versions. Runtime scripts read /vl/php_versions.
PHP_VERSIONS="8.3 8.4 8.5"
# Lowest accepted patch release per branch: the build fails instead of shipping an unpatched PHP.
# Current floor: the 2026-10-21 security release (CVE-2026-109618, CVE-2026-109619).
declare -A PHP_MIN=([8.3]=8.3.36 [8.4]=8.4.27 [8.5]=8.5.12)
# Alpine package suffixes (php83-<ext>) for the extension set the Debian images shipped.
PHP_EXTS="bcmath calendar ctype curl dom exif ffi fileinfo ftp gd gettext gmp iconv intl mbstring mysqli mysqlnd
    openssl pcntl pdo pdo_mysql pdo_sqlite pecl-apcu phar posix session shmop simplexml soap sockets sodium sqlite3
    sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"
# Modules `php -m` must list afterwards (OPcache is a package before 8.5 and built in from 8.5 on).
PHP_MODULES="apcu bcmath calendar ctype curl dom exif FFI fileinfo ftp gd gettext gmp iconv intl mbstring mysqli mysqlnd
    openssl pcntl PDO pdo_mysql pdo_sqlite Phar posix session shmop SimpleXML soap sockets sodium sqlite3 sysvmsg
    sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip zlib Zend.OPcache"

function createCMD() {
    local script_name="$1"
    local script_path="$2"
    if [ ! -f "$script_path/$script_name.sh" ]; then
        echo "[ERROR] Script $script_path/$script_name.sh does not exist."
        exit 1
    fi
    cp -f -v "$script_path/$script_name.sh" "/usr/bin/$script_name"
    chmod 555 "/usr/bin/$script_name"
    echo "[INFO] Command $script_name created successfully."
}

# apk_any <pkg>...: install the first package that exists; returns 1 if none does.
function apk_any() {
    local p
    for p in "$@"; do
        apk add --no-cache "$p" >/dev/null 2>&1 && { echo "[INFO] installed $p"; return 0; }
    done
    return 1
}

if [[ ! -d "/vl" ]]; then
    echo "[ERROR] /vl is missing. (BUILD ISSUE/FAULT)"
    exit 1
fi

echo "[INFO] Installing base packages on Alpine $(cat /etc/alpine-release)"
apk upgrade --no-cache
# GNU coreutils/findutils/grep/sed so scripts (ours and users' autorun.sh) behave as they did on Debian.
apk add --no-cache \
    bash coreutils findutils grep sed tar gzip zip unzip curl wget ca-certificates openssl gnupg \
    supervisor nano git tzdata python3

# www-data is uid/gid 33 as on Debian, so files in existing /web volumes keep their owner.
# Alpine's base has a www-data group with gid 82; replace it before any package can use it.
delgroup www-data 2>/dev/null || true
addgroup -S -g 33 www-data
adduser -S -D -H -u 33 -G www-data -h /var/www -s /sbin/nologin www-data
[ "$(id -u www-data):$(id -g www-data)" = "33:33" ] || { echo "[ERROR] www-data is not 33:33"; exit 1; }

for v in ${PHP_VERSIONS}; do
    p="php${v//./}"
    d="/etc/php/${v}"
    echo "[INFO] Installing PHP ${v}"
    pkgs="${p} ${p}-fpm"
    for e in ${PHP_EXTS}; do pkgs="${pkgs} ${p}-${e}"; done
    apk add --no-cache ${pkgs}
    apk_any "${p}-opcache" || echo "[INFO] ${p} has OPcache built in"
    apk_any "${p}-imap" "${p}-pecl-imap" || echo "[WARN] ${p}: no imap package, skipping"
    apk_any "${p}-pecl-xmlrpc" || echo "[WARN] ${p}: no xmlrpc package, skipping"

    # Same /etc/php/<v>/{cli,fpm} layout as the Debian images, so /config/php volumes, pool overrides, the
    # /run/php/php<v>-fpm.sock sockets and the php<v> / php-fpm<v> commands keep working. Alpine's /etc/phpNN
    # becomes the CLI config; FPM gets its php.ini with -c and its conf.d via PHP_INI_SCAN_DIR (phpfpm.conf).
    mkdir -p "${d}/cli" "${d}/fpm/pool.d"
    for sapi in cli fpm; do
        cp "/etc/${p}/php.ini" "${d}/${sapi}/php.ini"
        cp -r "/etc/${p}/conf.d" "${d}/${sapi}/conf.d"
    done
    sed "s|^include=/etc/${p}/php-fpm.d/\*.conf$|include=/etc/php/${v}/fpm/pool.d/*.conf|; s|^;error_log = .*|error_log = /var/log/php${v}-fpm.log|" \
        "/etc/${p}/php-fpm.conf" > "${d}/fpm/php-fpm.conf"
    sed -e "s|^user = nobody$|user = www-data|" -e "s|^group = nobody$|group = www-data|" \
        -e "s|^listen = 127.0.0.1:9000$|listen = /run/php/php${v}-fpm.sock|" \
        -e "s|^;listen.owner = nobody$|listen.owner = www-data|" -e "s|^;listen.group = nobody$|listen.group = www-data|" \
        "/etc/${p}/php-fpm.d/www.conf" > "${d}/fpm/pool.d/www.conf"
    for want in "include=/etc/php/${v}/fpm/pool.d/\*.conf" "error_log = /var/log/php${v}-fpm.log"; do
        grep -qx "${want}" "${d}/fpm/php-fpm.conf" || { echo "[ERROR] ${p}: php-fpm.conf template changed, missing '${want}'"; exit 1; }
    done
    for want in "user = www-data" "group = www-data" "listen = /run/php/php${v}-fpm.sock" "listen.owner = www-data" "listen.group = www-data"; do
        grep -qx "${want}" "${d}/fpm/pool.d/www.conf" || { echo "[ERROR] ${p}: www.conf template changed, missing '${want}'"; exit 1; }
    done
    rm -rf "/etc/${p}"
    ln -s "${d}/cli" "/etc/${p}"
    ln -sf "/usr/bin/${p}" "/usr/bin/php${v}"
    ln -sf "/usr/sbin/php-fpm${v//./}" "/usr/sbin/php-fpm${v}"

    loaded=" $(php${v} -m | grep -v '^\[' | tr ' ' '.' | tr '\n' ' ') "
    for m in ${PHP_MODULES}; do
        [[ "${loaded}" == *" ${m} "* ]] || { echo "[ERROR] php${v} is missing the ${m//./ } module"; exit 1; }
    done
    if ! php${v} -r "exit(version_compare(PHP_VERSION, '${PHP_MIN[$v]}', '>=') ? 0 : 1);"; then
        echo "[ERROR] php${v} is $(php${v} -r 'echo PHP_VERSION;'), need >= ${PHP_MIN[$v]} (security floor)"
        exit 1
    fi
    PHP_INI_SCAN_DIR="${d}/fpm/conf.d" "php-fpm${v}" -t --fpm-config "${d}/fpm/php-fpm.conf" -c "${d}/fpm/php.ini"
done
# `php` is the newest version, as Debian's alternatives picked it.
ln -sf "/usr/bin/php${PHP_VERSIONS##* }" /usr/bin/php
echo "${PHP_VERSIONS}" > /vl/php_versions

mkdir -p /run/php /var/run/supervisord /var/log
# supervisorctl (health_check, websrv, reloadPHPfpm, ...) reads /etc/supervisord.conf by default; point it at the
# config webcontainer-init generates so it talks to that supervisord's socket.
ln -sf /vl/supervisor.conf /etc/supervisord.conf

# Alpine has certbot but not certbot-dns-cloudflare, so both come from PyPI into their own venv.
echo "[INFO] Installing certbot with the Cloudflare DNS plugin"
python3 -m venv /opt/certbot
/opt/certbot/bin/pip install --no-cache-dir -q --upgrade pip
/opt/certbot/bin/pip install --no-cache-dir -q certbot certbot-dns-cloudflare
# pip is not needed at runtime, and its vendored libraries (urllib3, msgpack, ...) lag behind their fixes.
/opt/certbot/bin/python -m pip uninstall -y -q pip
ln -sf /opt/certbot/bin/certbot /usr/local/bin/certbot
certbot --version

echo "[INFO] Installing composer (signature verified against composer.github.io)"
EXPECTED_SIG="$(curl -fsSL https://composer.github.io/installer.sig)"
curl -fsSLo /tmp/composer-setup.php https://getcomposer.org/installer
echo "${EXPECTED_SIG}  /tmp/composer-setup.php" | sha384sum -c -
php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm -f /tmp/composer-setup.php

echo "[INFO] Creating new commands to use"
createCMD "reloadCron" "/intcmd"
createCMD "generateSupervisorConfig" "/intcmd"
createCMD "applypermissions" "/intcmd"
createCMD "lazymount" "/intcmd"
createCMD "websrv" "/intcmd"
createCMD "reloadPHPfpm" "/intcmd"
createCMD "webcontainer-init" "/intcmd"
createCMD "background_le_ssl_renew" "/intcmd/background"
createCMD "health_check" "/intcmd/background"
createCMD "renewLEAllCert" "/intcmd/letsencrypt"
createCMD "createLECert" "/intcmd/letsencrypt"
createCMD "cleanLEExpired" "/intcmd/letsencrypt"
rm -rf /intcmd

# Compatibility: older deployments start the container with "bash /init.sh".
printf '#!/usr/bin/env bash
exec webcontainer-init "$@"
' > /init.sh
chmod 755 /init.sh

supercronic -version

rm -rf /var/cache/apk/* /root/.cache
echo "[INFO] Task done!"
