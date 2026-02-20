#!/usr/bin/env bash
checkDir() {
    [ -d "$@" ]
}

checkFile() {
    [ -f "$@" ]
}

certStuffRoot="/web/cert_webroot"
sslDirPath="/web/ssl"
sslLiveDirPath="/web/ssl/live"
logFile="/scripts/letsencrypt/letsencrypt-renew.log"

if ! checkDir $certStuffRoot; then
    echo "Creating cert_webroot folder"
    mkdir -p $certStuffRoot
fi

if ! checkDir $sslDirPath; then
    echo "Creating SSL folder"
    mkdir -p $sslDirPath
fi

if ! checkFile $logFile; then
    echo "Creating Log File"
    touch $logFile
fi

function renew() {
    local certName="$1"
    local WEBROOT_OPTS="--webroot --webroot-path $certStuffRoot"
    local CLOUDFLARE_USED=false
    if [ -f "/cloudflare-account.ini" ]; then
        echo "Using CloudFlare API for DNS"
        WEBROOT_OPTS="--dns-cloudflare --dns-cloudflare-credentials /cloudflare-account.ini"
        CLOUDFLARE_USED=true
    fi
    echo "Renewing certificate for $certName"
    certbot renew --config-dir $sslDirPath $WEBROOT_OPTS --cert-name "$certName"
    if [ $? -ne 0 ]; then
        echo "Failed to renew certificate for $certName"
        if [ "$CLOUDFLARE_USED" = true ]; then
            echo "Please check your CloudFlare API credentials and permissions. Using webroot method as a fallback."
            unset WEBROOT_OPTS
             WEBROOT_OPTS="--webroot --webroot-path $certStuffRoot"
             certbot renew --config-dir $sslDirPath $WEBROOT_OPTS --cert-name "$certName"
             if [ $? -ne 0 ]; then
                 echo "Failed to renew certificate for $certName using webroot method as well."
                 return 1
             else
                 echo "Successfully renewed certificate for $certName using webroot method."
                 return 0
             fi
        fi
        return 1
    fi
}

for certPath in "$sslLiveDirPath"/*; do
    if [ -d "$certPath" ]; then
        certName=$(basename "$certPath")
        renew "$certName"
    fi
done
