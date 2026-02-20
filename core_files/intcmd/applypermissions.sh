#!/usr/bin/env bash

WWDATA_PERMISSION_CODE=0755
WWWDATA_PATHS=("/run/php" "/web" "/usr/local/openresty")

while true; do
    for path in "${WWWDATA_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            echo "[INFO] Setting permissions for $path to $WWDATA_PERMISSION_CODE"
            FINAL_PERMCODE="$WWDATA_PERMISSION_CODE"
            if [[ "$path" == "/run/php" ]]; then
                FINAL_PERMCODE=0777
                echo "[INFO] Special case for $path: setting permissions to $FINAL_PERMCODE"
            fi
            chmod -R "$FINAL_PERMCODE" "$path"
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