#!/usr/bin/env bash

function reloadService() {
    local service_name="$1"
    local status=$(supervisorctl status "${service_name}" | awk '{print $2}')
    if [ "$status" == "RUNNING" ]; then
        echo "Stopping $service_name..."
        supervisorctl stop "$service_name"
        if [ $? -ne 0 ]; then
            echo "Failed to stop $service_name."
            exit 1
        fi
        echo "$service_name stopped successfully."
    fi
    echo "Starting $service_name..."
    supervisorctl start "$service_name"
    if [ $? -ne 0 ]; then
        echo "Failed to start $service_name."
        exit 1
    fi
    echo "$service_name started successfully."
}

chmod 0777 -R /run/php
chown www-data:www-data -R /run/php

reloadService "php7.4-fpm"
reloadService "php8.3-fpm"