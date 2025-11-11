#!/usr/bin/env bash

JSON_CONFIG="/scfg/permissions.json"

if [ ! -f "${JSON_CONFIG}" ]; then
    echo "[Error] Unable to locate '${JSON_CONFIG}'"
    exit 1
fi

function getJSONValue() {
    local key="$1"
    local data=$(jq -r ".$key" "$JSON_CONFIG")
    if [ $? -ne 0 ] || [ -z "$data" ] || [ "$data" == "null" ]; then
      echo ""
    else
      echo "$data"
    fi
}

function getJSONValueKeys() {
    local key="$1"
    local data=$(jq -r ".$key | keys_unsorted[]" "$JSON_CONFIG")
    if [ $? -ne 0 ] || [ -z "$data" ] || [ "$data" == "null" ]; then
      echo ""
    else
      echo "$data"
    fi
}

while true; do
    DATA_STREAM_PATHS=$(getJSONValueKeys "paths")
    for DATA_STREAM_PATH in $DATA_STREAM_PATHS; do
        unset DATA_STREAM_PATH_MOD
        DATA_STREAM_PATH_MOD=$(getJSONValue "paths.${DATA_STREAM_PATH_MOD}")
        if [ ! -z "${DATA_STREAM_PATH }" ]; then
            if [ ! -z "${DATA_STREAM_PATH_MOD}" ]; then
                if chmod -R "${DATA_STREAM_PATH_MOD}" "${DATA_STREAM_PATH}"; then
                    echo "[INFO] Updated Path '${DATA_STREAM_PATH}' permissions mod to ${DATA_STREAM_PATH_MOD}"
                else
                    echo "[WARNING] Unable to set path '${DATA_STREAM_PATH}' permissions mod due to executing command error!"
                fi
            else
                echo "[WARNING] Unable to set path '${DATA_STREAM_PATH}' permissions mod due to mod value is null or empty!"
            fi
        fi
    done 
    echo "[INFO] Permission fix completed. Sleeping for 5 seconds."
    sleep 5
done
