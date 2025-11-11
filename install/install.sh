#!/usr/bin/env bash

SUPERCRON_VERSION="0.2.37"

function get_arch() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l) echo "arm" ;;
        *) echo "Unsupported architecture: $arch" && exit 1 ;;
    esac
}

function createCMD() {
    local script_name="$1"
    local script_path="$2"
    if [ -z "$script_name" ]; then
        echo "[ERROR] No script name provided to createCMD function."
        exit 1
    fi
    if [ -z "$script_path" ]; then
        echo "[ERROR] No script path provided to createCMD function."
        exit 1
    fi
    if [ ! -f "$script_path/$script_name.sh" ]; then
        echo "[ERROR] Script $script_path/$script_name.sh does not exist."
        exit 1
    fi
    cp -r -f -v "$script_path/$script_name.sh" "/usr/bin/$script_name"
    chmod 555 "/usr/bin/$script_name"
    if [ $? -ne 0 ]; then
        echo "[ERROR] Failed to create command for $script_name."
        exit 1
    fi
    echo "[INFO] Command $script_name created successfully."
}

if [[ ! -d "/vl" ]]; then
    echo "[ERROR] This script must be run from the /vl directory. (BUILD ISSUE/FAULT)"
    exit 1
fi

echo "[INFO] Starting installation of required packages and tools"
apt-get update
apt-get full-upgrade -y

apt-get install -y supervisor curl wget gnupg neovim nano vim emacs apt-utils iftop iptraf jq wget git zip tar unzip bmon iptraf socat bash-completion certbot cron inetutils-ping software-properties-common ca-certificates lsb-release apt-transport-https python3 python2 python3-certbot-dns-cloudflare zsh

sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' 
wget -qO - https://packages.sury.org/php/apt.gpg | apt-key add - 
apt-get update

apt-get install -y php7.4 php7.4-{fpm,common,mysql,gmp,curl,intl,mbstring,xmlrpc,gd,xml,cli,zip,soap,imap,sqlite3,bcmath,apcu,zip,phar,iconv}
apt-get install -y php8.3 php8.3-{fpm,common,mysql,gmp,curl,intl,mbstring,xmlrpc,gd,xml,cli,zip,soap,imap,sqlite,bcmath,apcu,zip,phar,iconv}

mkdir -p /run/php
mkdir -p /var/run/supervisord

curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

echo "[INFO] Creating new commands to use"

createCMD "reloadCron" "/intcmd"
createCMD "generateSupervisorConfig" "/intcmd"
createCMD "applypermissions" "/intcmd"
createCMD "lazymount" "/intcmd"
createCMD "websrv" "/intcmd"
createCMD "reloadPHPfpm" "/intcmd"

createCMD "background_le_ssl_renew" "/intcmd/background"
createCMD "health_check" "/intcmd/background"
createCMD "pathChecker" "/intcmd/background"

createCMD "renewLEAllCert" "/intcmd/letsencrypt"
createCMD "createLECert" "/intcmd/letsencrypt"

rm -rf /intcmd

chmod -R 777 /var/log
chmod -R 777 /run/php

echo "[INFO] Installing supercronic"
ARCH=$(get_arch)
mkdir -p /tmp/supercron-dl
cd /tmp/supercron-dl
curl -fsSLO https://github.com/aptible/supercronic/releases/download/v${SUPERCRON_VERSION}/supercronic-linux-${ARCH}
mv supercronic-linux-${ARCH} supercronic
chmod +x supercronic
mv supercronic /usr/local/bin/supercronic

echo "[INFO] Task done!"
