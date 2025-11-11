#!/usr/bin/env bash

LOCK_FILE="/tmp/lazymount.lock"



if [[ -f "$LOCK_FILE" ]]; then
    echo "[ERROR] Lazy mount script is already executed. Exiting to prevent multiple executions. (This is only supposed to run once at container start)"
    exit 1
else
    echo "[INFO] Creating lock file to prevent multiple executions..."
    touch "$LOCK_FILE"
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Failed to create lock file: $LOCK_FILE"
        exit 1
    fi
fi

declare -A MOUNTS

MOUNTS["/etc/php"]="/config/php"

if [ -f "/mounts" ]; then
  source /mounts
fi

#if [ -d "/usr/local/share/lua/5.4" ]; then
#  echo "Mounting Custom Lua Directory"
#  MOUNTS["/usr/local/share/lua/5.4"]="/config/lua"
#fi

for to_path in "${!MOUNTS[@]}"; do
  set -Eeuo pipefail
  echo "From Path: ${MOUNTS[${to_path}]} To Path: ${to_path}"
  from_path="${MOUNTS[${to_path}]}"
  rm -rf "${to_path}"
  if [ ! -d "$from_path" ]; then
    echo "[INFO] Creating Directory '$from_path' and applying permissions"
    mkdir -vp "$from_path"
  fi
  chmod -R 777 "$from_path"
  mkdir -vp "$(dirname "${to_path}")"
  ln -sT "${from_path}" "${to_path}"
  echo Mounted $(basename "${from_path}")
done