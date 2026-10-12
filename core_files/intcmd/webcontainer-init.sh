#!/usr/bin/env bash
# Container entrypoint shared by the nginx and openresty images.

CLEAN_PATH="/clean"
AUTORUN_PATH="/web/config/autorun.sh"

output() {
    echo "Output: $@"
}

isEmptyDir() {
    [ -n "$(find "$@" -maxdepth 0 -type d -empty 2>/dev/null)" ]
}

if [ -d "/usr/local/openresty" ]; then
    WEBSRV_CONF="openresty"
else
    WEBSRV_CONF="nginx"
fi

if [[ -n "${BACKEND_RENEW_LESSL:-}" && "${BACKEND_RENEW_LESSL}" != "true" && "${BACKEND_RENEW_LESSL}" != "false" ]]; then
    echo "[WARNING] BACKEND_RENEW_LESSL must be 'true' or 'false'. Defaulting to 'false'."
    export BACKEND_RENEW_LESSL=false
fi

if [ ! -d "$CLEAN_PATH" ] || isEmptyDir "$CLEAN_PATH"; then
    output "Clean configuration was not found! Corrupt or incomplete docker build of this container! Exiting"
    exit 1
fi
output "Clean configuration folder was found!"

if isEmptyDir "/config"; then
    output "Copying clean config data"
    cp -r -f "$CLEAN_PATH"/config/* /config
fi

for sub in php "$WEBSRV_CONF"; do
    if [ ! -d "/config/$sub" ] || isEmptyDir "/config/$sub"; then
        output "Failed to validate /config/$sub. Copying defaults"
        mkdir -p "/config/$sub"
        cp -r -f "$CLEAN_PATH/config/$sub"/* "/config/$sub"
    fi
done

if isEmptyDir "/scripts"; then
    output "Copying clean script data"
    cp -r -f "$CLEAN_PATH"/scripts/* /scripts
fi

lazymount
generateSupervisorConfig
bash /scripts/pathChecker.sh

if [ ! -f "$AUTORUN_PATH" ]; then
    output "Creating Autorun Script File!"
    echo "#!/usr/bin/env bash" > "$AUTORUN_PATH"
fi
chmod +x "$AUTORUN_PATH"
bash "$AUTORUN_PATH"

chmod 755 -R /scripts/*
applypermissions

exec supervisord -c /vl/supervisor.conf
