#!/usr/bin/env bash

function reloadService() {
    local service_name="$1"
    local status=$(supervisorctl status "${service_name}" | awk '{print $2}')
    if [ "$status" == "RUNNING" ]; then
        echo "Stopping $service_name..."
        supervisorctl stop "$service_name" || { echo "Failed to stop $service_name."; exit 1; }
    fi
    echo "Starting $service_name..."
    supervisorctl start "$service_name" || { echo "Failed to start $service_name."; exit 1; }
    echo "$service_name started successfully."
}

chown www-data:www-data -R /run/php
chmod u=rwX,go=rX -R /run/php

for v in $(cat /vl/php_versions); do
    reloadService "php${v}-fpm"
done
