#!/usr/bin/env bash

WWDATA_PERMISSION_CODE=0755
WWWDATA_PATHS=("/web" "/usr/local/openresty")

while true; do
    for path in "${WWWDATA_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            echo "[INFO] Setting permissions for $path to $WWDATA_PERMISSION_CODE"
            chmod -R "$WWDATA_PERMISSION_CODE" "$path"
            if [[ $? -ne 0 ]]; then
                echo "[ERROR] Failed to set permissions for $path"
            else
                echo "[INFO] Permissions for $path set successfully."
            fi
        else
            echo "[WARNING] Path $path does not exist, skipping."
        fi
    done
    echo "[INFO] Permission fix completed. Sleeping for 5 seconds."
    sleep 5
done