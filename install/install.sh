#!/usr/bin/env bash
set -euo pipefail

# Single source of truth for shipped PHP versions. Runtime scripts read /vl/php_versions.
PHP_VERSIONS="8.4 8.5"

SUPERCRON_VERSION="0.2.49"
SUPERCRON_SHA1_amd64="e63c11a9726b775a6a11801e81af4f3fb926aa68"
SUPERCRON_SHA1_arm64="0b6c5bb743e0b0dafed1132198c81807927ac413"

function get_arch() {
    case "$(uname -m)" in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *) echo "Unsupported architecture: $(uname -m)" >&2 && exit 1 ;;
    esac
}

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

if [[ ! -d "/vl" ]]; then
    echo "[ERROR] /vl is missing. (BUILD ISSUE/FAULT)"
    exit 1
fi

. /etc/os-release
echo "[INFO] Installing base packages on Debian ${VERSION_CODENAME}"
apt-get update
apt-get full-upgrade -y
apt-get install -y --no-install-recommends \
    supervisor curl wget gnupg ca-certificates apt-utils \
    nano git zip unzip tar inetutils-ping \
    python3 certbot python3-certbot-dns-cloudflare

echo "[INFO] Adding packages.sury.org PHP repository"
curl -fsSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/php.list
apt-get update

for v in ${PHP_VERSIONS}; do
    echo "[INFO] Installing PHP ${v}"
    apt-get install -y --no-install-recommends \
        php${v} php${v}-{fpm,common,cli,mysql,gmp,curl,intl,mbstring,gd,xml,zip,soap,sqlite3,bcmath,apcu}
    # PECL-only extensions: not every version has a package yet, so these are best effort.
    for ext in xmlrpc imap; do
        apt-get install -y --no-install-recommends php${v}-${ext} || echo "[WARN] php${v}-${ext} not available, skipping"
    done
done
echo "${PHP_VERSIONS}" > /vl/php_versions

mkdir -p /run/php /var/run/supervisord

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
rm -rf /intcmd

echo "[INFO] Installing supercronic ${SUPERCRON_VERSION}"
ARCH="$(get_arch)"
SHA_VAR="SUPERCRON_SHA1_${ARCH}"
curl -fsSLo /usr/local/bin/supercronic "https://github.com/aptible/supercronic/releases/download/v${SUPERCRON_VERSION}/supercronic-linux-${ARCH}"
echo "${!SHA_VAR}  /usr/local/bin/supercronic" | sha1sum -c -
chmod 755 /usr/local/bin/supercronic

apt-get clean
rm -rf /var/lib/apt/lists/*
echo "[INFO] Task done!"
