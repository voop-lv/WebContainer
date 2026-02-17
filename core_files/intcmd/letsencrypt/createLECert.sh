#!/usr/bin/env bash
checkDir() {
    [ -d "$@" ]
}

certStuffRoot="/web/cert_webroot"
sslDirPath="/web/ssl"

if ! checkDir $certStuffRoot; then
    echo "Creating cert_webroot folder"
    mkdir -p $certStuffRoot
fi

if ! checkDir $sslDirPath; then
    echo "Creating ssl folder"
    mkdir -p $sslDirPath
fi

WEBROOT_OPTS="--webroot --webroot-path $certStuffRoot"
CLOUDFLARE_USED=false
if [ -f "/cloudflare-account.ini" ]; then
    echo "Using CloudFlare API for DNS"
    WEBROOT_OPTS="--dns-cloudflare --dns-cloudflare-credentials /cloudflare-account.ini"
    unset CLOUDFLARE_USED
    CLOUDFLARE_USED=true
fi

echo "Creating a cert for ${1}"
certbot certonly --config-dir $sslDirPath $WEBROOT_OPTS -n --agree-tos --register-unsafely-without-email -d ${1}
if [ $? -ne 0 ]; then
    echo "[Failure] Unable to create certificate '${1}' due to an error"
    if [ $CLOUDFLARE_USED = true ]; then
        echo "If you are using CloudFlare DNS, make sure your API key and email are correct in /cloudflare-account.ini! Using webroot method!"
        unset WEBROOT_OPTS
        WEBROOT_OPTS="--webroot --webroot-path $certStuffRoot"
        certbot certonly --config-dir $sslDirPath $WEBROOT_OPTS -n --agree-tos --register-unsafely-without-email -d ${1}
        if [ $? -ne 0 ]; then
            echo "[Failure] Unable to create certificate '${1}' using webroot method as well. Please check your configuration and try again."
            exit 1
        else
            echo "Certificate created successfully using webroot method. Please check your configuration for CloudFlare DNS and try again if you want to use that method."
            exit 0
        fi
    fi
    exit 1
else
    echo "End of script have a nice day! Enjoy you're new cert if it was created"
    exit 0
fi
