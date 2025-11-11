#!/usr/bin/env bash

SCFG_PATH="/scfg"

checkDir() {
    [ -d "$@" ]
} 

checkFile() {
    [ -f "$@" ]
}

checkDirAndMake() {
    if ! checkDir "$@"; then
      mkdir -p "$@"
    fi
}

if [ ! -f "${SCFG_PATH}" ]; then
    echo "[ERROR] Unable to locate '${SCFG_PATH}'"
    exit 1
fi

declare -A PATHS
declare -A PATHS_COPY

if [ -f "${SCFG_PATH}/paths" ]; then
    source "${SCFG_PATH}/paths"
fi

if [ -f "${SCFG_PATH}/paths_copy" ]; then
    source "${SCFG_PATH}/paths_copy"
fi

for path in "${!PATHS[@]}"; do
    checkDirAndMake "${path}"
done

WEB_DATA="/web/data"
CERT_WEBROOT="/web/cert_webroot"
SSL_DIR="/web/ssl/"
AUTORUN_PATH="/web/config/autorun.sh"

checkDirAndMake $CERT_WEBROOT
checkDirAndMake $SSL_DIR

if ! checkDir $WEB_DATA; then
    mkdir -p $WEB_DATA/default_page
    for pathcopy in "${!PATHS_COPY[@]}"; do
        cp -r -f "${pathcopy}" "${PATHS_COPY[${pathcopy}]}"
    done
    touch newinstall
fi

if ! checkFile $AUTORUN_PATH; then
    touch $AUTORUN_PATH
    echo "#!/usr/bin/env bash" >> $AUTORUN_PATH
fi