#!/usr/bin/env bash

# WORK IN PROGRESS
ROOT_PATH="/vl"
ROOT_SUPERVISOR_PATH="${ROOT_PATH}/supervisord"
USER_PROVIDED_CONFIG_PATH="/config/supervisor-usr.conf"
TEMP_CONFIG_PATH="/tmp/supervisor.conf"
LOCK_FILE="/tmp/supervisor_config.lock"

if [[ -f "$LOCK_FILE" ]]; then
    echo "[ERROR] Generation of supervisor configuration was executed! Please restart the container to generate a new configuration."
    exit 1
else
    echo "[INFO] Creating lock file to prevent multiple executions..."
    touch "$LOCK_FILE"
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Failed to create lock file: $LOCK_FILE"
        exit 1
    fi
fi

cleanUpTemp() {
    if [[ -f "$TEMP_CONFIG_PATH" ]]; then
        echo "[INFO] Cleaning up temporary configuration file..."
        rm "$TEMP_CONFIG_PATH"
        echo "[INFO] Temporary configuration file removed."
    else
        echo "[INFO] No temporary configuration file to clean up."
    fi
}

trap cleanUpTemp EXIT SIGHUP SIGINT SIGTERM

addSpacer() {
    echo "" >> "$TEMP_CONFIG_PATH"
}

function validatePath() {
    local path="$1"
    if [[ -z "$path" ]]; then
        echo "Error: Path cannot be empty."
        exit 1
    fi
    if [[ ! -d "$path" ]]; then
        echo "Error: Path '$path' does not exist or is not a directory."
        exit 1
    fi
    echo "[INFO] Path '$path' is valid."
}

function generatePHPConfig() {
    local version="$1"
    if [[ -z "$version" ]]; then
        echo "Error: PHP version cannot be empty."
    else
        if [[ ! "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
            echo "Error: Invalid PHP version format. Expected format is X.Y (e.g., 8.0, 7.1)."
        else
            local template_file="${ROOT_SUPERVISOR_PATH}/templates/phpfpm.conf"
            if [[ -f "$template_file" ]]; then
                addSpacer
                while IFS= read -r line; do
                    if [[ -n "$line" ]]; then
                        echo "$line" | sed "s/{PHP_VERSION}/$version/g" >> "$TEMP_CONFIG_PATH"
                    else
                        echo "" >> "$TEMP_CONFIG_PATH"
                    fi
                done < "$template_file"
            fi
        fi
    fi
}

function applyFromConfig() {
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then
        echo "[ERROR] Configuration file '$config_file' does not exist."
    else
        echo "[INFO] Applying configuration from $config_file to $TEMP_CONFIG_PATH..."
        addSpacer
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                echo "$line" >> "$TEMP_CONFIG_PATH"
            else
                echo "" >> "$TEMP_CONFIG_PATH"
            fi
        done < "$config_file"
        echo "[INFO] Configuration from $config_file applied successfully."
    fi
}

echo "[NOTICE] WORK IN PROGRESS: This script is under development and may not function as expected."

if [[ ! -d "$ROOT_SUPERVISOR_PATH" ]]; then
    mkdir -p "$ROOT_SUPERVISOR_PATH"
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Failed to create directory: $ROOT_SUPERVISOR_PATH"
        exit 1
    fi
    echo "[INFO] Created directory: $ROOT_SUPERVISOR_PATH"
fi

if [ -f "$TEMP_CONFIG_PATH" ]; then
    echo "[INFO] Removing existing temporary configuration file..."
    rm "$TEMP_CONFIG_PATH"
fi

touch "$TEMP_CONFIG_PATH"
echo "[INFO] Temporary configuration file created at $TEMP_CONFIG_PATH."

applyFromConfig "${ROOT_SUPERVISOR_PATH}/core.conf"

if [[ ! -z "${BACKEND_RENEW_LESSL}" ]]; then
    BACKEND_RENEW_LESSL=$(echo "${BACKEND_RENEW_LESSL}" | tr '[:upper:]' '[:lower:]')
    if [[ "${BACKEND_RENEW_LESSL}" != "true" && "${BACKEND_RENEW_LESSL}" != "false" ]]; then
        echo "[ERROR] BACKEND_RENEW_LESSL must be set to 'true' or 'false'."
    fi
    if [[ "${BACKEND_RENEW_LESSL}" != "true" ]]; then
        echo "[INFO] BACKEND_RENEW_LESSL is not set to true"
    else
        echo "[INFO] BACKEND_RENEW_LESSL is set to true, applying le_ssl_new.conf"
        applyFromConfig "${ROOT_SUPERVISOR_PATH}/optional/le_ssl_new.conf"
    fi
fi

addSpacer
for v in $(cat /vl/php_versions); do
    generatePHPConfig "$v"
done

if [[ -f "${ROOT_SUPERVISOR_PATH}/1_pack.conf" ]]; then
    echo "[INFO] Applying pack configuration..."
    applyFromConfig "${ROOT_SUPERVISOR_PATH}/1_pack.conf"
else
    echo "[ERROR] Pack configuration file not found: ${ROOT_SUPERVISOR_PATH}/1_pack.conf [Build issue?]"
    exit 1
fi

if [[ -f "${USER_PROVIDED_CONFIG_PATH}" ]]; then
    echo "[INFO] Applying user-provided configuration from ${USER_PROVIDED_CONFIG_PATH}..."
    applyFromConfig "${USER_PROVIDED_CONFIG_PATH}"
else
    echo "[INFO] No user-provided configuration file found at ${USER_PROVIDED_CONFIG_PATH}. Skipping."
fi

echo "[INFO] Moving temporary configuration to final location..."
mv "$TEMP_CONFIG_PATH" "${ROOT_PATH}/supervisor.conf"
echo "[INFO] Supervisor configuration generated successfully at ${ROOT_PATH}/supervisor.conf"
echo "[INFO] Supervisor configuration generation completed."
exit 0