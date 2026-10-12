#!/usr/bin/env bash

LE_SSL_DIR="/web/ssl"
CERT_WEBROOT="/web/cert_webroot"
CLOUDFLARE_ACCOUNT_FILE="/cloudflare-account.ini"

function validatePaths() {
    if [[ ! -d "$LE_SSL_DIR" ]]; then
        echo "[INFO] Creating Let's Encrypt SSL directory: $LE_SSL_DIR"
        mkdir -p "$LE_SSL_DIR"
        if [[ $? -ne 0 ]]; then
            echo "[ERROR] Failed to create Let's Encrypt SSL directory: $LE_SSL_DIR"
            exit 1
        fi
    fi

    if [[ ! -d "$CERT_WEBROOT" ]]; then
        echo "[INFO] Creating certificate webroot directory: $CERT_WEBROOT"
        mkdir -p "$CERT_WEBROOT"
        if [[ $? -ne 0 ]]; then
            echo "[ERROR] Failed to create certificate webroot directory: $CERT_WEBROOT"
            exit 1 
        fi
    fi
}

function renewCertificates() {
    echo "[INFO] Starting certificate renewal process..."
    local WEBROOT_OPTS="--webroot --webroot-path $CERT_WEBROOT"
    if [[ -f "$CLOUDFLARE_ACCOUNT_FILE" ]]; then
        echo "[INFO] Cloudflare credentials file found, using DNS challenge."
        WEBROOT_OPTS=" --dns-cloudflare --dns-cloudflare-credentials $CLOUDFLARE_ACCOUNT_FILE"
    fi
    certbot renew --config-dir ${LE_SSL_DIR} ${WEBROOT_OPTS}
    if [[ $? -ne 0 ]]; then
        echo "[WARNING] Some Certificate renewal failed."
    else
        echo "[INFO] Certificate renewal completed successfully."
    fi
}

while true; do
    if [[ -z "${BACKEND_RENEW_LESSL}" ]]; then
        break
    fi
    BACKEND_RENEW_LESSL=$(echo "${BACKEND_RENEW_LESSL}" | tr '[:upper:]' '[:lower:]')
    if [[ "${BACKEND_RENEW_LESSL}" != "true" && "${BACKEND_RENEW_LESSL}" != "false" ]]; then
        echo "[ERROR] BACKEND_RENEW_LESSL must be set to 'true' or 'false'."
        break
    fi
    if [[ "${BACKEND_RENEW_LESSL}" != "true" ]]; then
        echo "[INFO] BACKEND_RENEW_LESSL is not set to true, skipping renewal."
        break
    fi
    validatePaths
    renewCertificates
    echo "[INFO] Waiting for 12 hours before the next renewal check..."
    sleep 43200
done

echo "[INFO] Exiting background renewal script."
exit 0