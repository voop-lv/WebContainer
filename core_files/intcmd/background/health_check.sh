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

# Certificates enabled sites use that are expired or cannot be renewed (expired-cert:<name>, broken-renewal:<name>)
for problem in $(cleanLEExpired --check); do
    NOTOKAY="${NOTOKAY} ${problem}"
done

if [ -z "$NOTOKAY" ]; then
    echo "[HEALTHCHECK] All services are running fine."
    exit 0
fi
echo "[HEALTHCHECK] Problems:${NOTOKAY}"
exit 1
