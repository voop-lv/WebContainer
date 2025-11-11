#!/usr/bin/env bash

nginx_root="/etc/nginx"
nginx_custom="/config/nginx"

php_root="/etc/php"
php_custom="/config/php"

crontab_file="/config/cronTasks"

AUTORUN_PATH="/web/config/autorun.sh"
WEBLAUNCH_SCRIPT="/launchWeb.sh"

CLEAN_PATH="/clean"

NEWINSTALL="/newinstall"

AUTO_UPDATE="/web/config/.auto_update"

output() {
    echo "Output: $@"
}

checkDir() {
    [ -d "$@" ]
}

checkFile() {
    [ -f "$@" ]
}

isEmptyDir() {
    [ -n "$(find "$@" -maxdepth 0 -type d -empty 2>/dev/null)" ]
}

if [[ -z "${BACKEND_RENEW_LESSL}" ]]; then
    BACKEND_RENEW_LESSL=false
else
    if [[ "${BACKEND_RENEW_LESSL}" != "true" && "${BACKEND_RENEW_LESSL}" != "false" ]]; then
        echo "[WARNING] BACKEND_RENEW_LESSL must be set to 'true' or 'false'. Defaulting to 'false'."
        unset BACKEND_RENEW_LESSL
        BACKEND_RENEW_LESSL=false
        sleep 5
    fi
fi

lazymount
generateSupervisorConfig
bash /scripts/pathChecker.sh

if checkDir "/clean"; then
    if isEmptyDir $CLEAN_PATH; then
        output "Clean configuration was not found! Corrupt of incomplete docker build of this container! Exiting"
        exit 1
    else
        output "Clean configuration folder was found!"    
    fi
else
    output "Clean configuration was not found! Corrupt of incomplete docker build of this container! Exiting"
    exit 1
fi

if checkDir "/install"; then 
    output "Found install dir, removing it"
    rm -rf /install;
fi

if isEmptyDir "/config"; then 
    output "Copying clean config data"
    cp -r -f -v $CLEAN_PATH/config/* /config    
fi

if ! checkDir "/config/php"; then
    output "Failed to validate php config directory. Copying defaults"
    mkdir -p $php_custom
    cp -r -f -v $CLEAN_PATH/config/php/* $php_custom
fi

if isEmptyDir "/config/php"; then
    output "Failed to validate php config directory. Copying defaults"
    cp -r -f -v $CLEAN_PATH/config/php/* $php_custom
fi

if ! checkDir "/config/nginx"; then
    output "Failed to validate nginx config directory. Copying defaults"
    cp -r -f -v $CLEAN_PATH/config/nginx/ /config
fi

apt-get update
if checkFile $AUTO_UPDATE; then
    apt-get full-upgrade -y
fi

if ! checkFile $NEWINSTALL; then
    rm -rf $NEWINSTALL
fi

if ! checkFile $AUTORUN_PATH; then 
    output "Creating Autorun Script File!"
    touch $AUTORUN_PATH
    echo "#!/usr/bin/env bash" >> $AUTORUN_PATH
fi

chmod +x $AUTORUN_PATH
bash $AUTORUN_PATH

chmod 755 -R /scripts/*
chmod -R 777 /var/log
chmod -R 777 /run/php
chmod -R 755 /usr/local/openresty
chown -R www-data:www-data /usr/local/openresty

supervisord -c /vl/supervisord.conf