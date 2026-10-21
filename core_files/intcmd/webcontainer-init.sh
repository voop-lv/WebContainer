#!/usr/bin/env bash
# Container entrypoint shared by the nginx, openresty, caddy and apache images.

CLEAN_PATH="/clean"
AUTORUN_PATH="/web/config/autorun.sh"

output() {
    echo "Output: $@"
}

isEmptyDir() {
    [ -n "$(find "$@" -maxdepth 0 -type d -empty 2>/dev/null)" ]
}

if [[ -n "${BACKEND_RENEW_LESSL:-}" && "${BACKEND_RENEW_LESSL}" != "true" && "${BACKEND_RENEW_LESSL}" != "false" ]]; then
    echo "[WARNING] BACKEND_RENEW_LESSL must be 'true' or 'false'. Defaulting to 'false'."
    export BACKEND_RENEW_LESSL=false
fi

if [ ! -d "$CLEAN_PATH" ] || isEmptyDir "$CLEAN_PATH"; then
    output "Clean configuration was not found! Corrupt or incomplete docker build of this container! Exiting"
    exit 1
fi
output "Clean configuration folder was found!"

# Seed anything missing from the shipped defaults (new PHP versions, new includes) without
# overwriting files the user already has.
output "Seeding missing defaults into /config and /scripts"
mkdir -p /config /scripts
cp -r -n "$CLEAN_PATH/config/." /config/
cp -r -n "$CLEAN_PATH/scripts/." /scripts/

# The hardening overlay is image-owned (users override per pool), so security changes must reach existing volumes.
for v in $(cat /vl/php_versions); do
    cp -f "$CLEAN_PATH/config/php/$v/fpm/conf.d/99-hardening.ini" "/config/php/$v/fpm/conf.d/99-hardening.ini"
done

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
