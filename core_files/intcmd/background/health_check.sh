#!/usr/bin/env bash

SERVICES="webserver supercronic"
for v in $(cat /vl/php_versions); do
    SERVICES="${SERVICES} php${v}-fpm"
done

NOTOKAY=""
for svc in ${SERVICES}; do
    status=$(supervisorctl status "${svc}" | awk '{print $2}')
    if [ "$status" != "RUNNING" ]; then
        NOTOKAY="${NOTOKAY} ${svc}"
    fi
done

if [ -z "$NOTOKAY" ]; then
    echo "[HEALTHCHECK] All services are running fine."
    exit 0
fi
echo "[HEALTHCHECK] Services not running:${NOTOKAY}"
exit 1
