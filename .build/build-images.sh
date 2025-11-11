#!/bin/bash

SCRIPT_DIR=$(cd $(dirname $0); pwd)
ROOT_DIR=$(cd ${SCRIPT_DIR}/..; pwd)

BASE_CORE_IMAGE=""
BASE_IMAGE_NAME="webcontainer"
BASE_TAG="dev_caddytest"

S_SET_ALL=true
S_SET_CADDY_ONLY=false
S_SET_OPENRESTY_ONLY=false
S_SET_NGINX_ONLY=false
S_SET_CORE_ONLY=false

function print_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --caddy-only        Build only the Caddy image"
    echo "  --openresty-only    Build only the OpenResty image"
    echo "  --nginx-only        Build only the Nginx image"
    echo "  --core-only         Build only the Core image"
    echo "  -h, --help          Show this help message and exit"
}

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            print_usage
            exit 0
            ;;
        --caddy-only)
            unset S_SET_ALL S_SET_CADDY_ONLY
            S_SET_ALL=false
            S_SET_CADDY_ONLY=true
            ;;
        --openresty-only)
            unset S_SET_ALL S_SET_OPENRESTY_ONLY
            S_SET_ALL=false
            S_SET_OPENRESTY_ONLY=true
            ;;
        --nginx-only )
            unset S_SET_ALL S_SET_NGINX_ONLY
            S_SET_ALL=false
            S_SET_NGINX_ONLY=true
            ;;
        --core-only)
            unset S_SET_ALL S_SET_CORE_ONLY
            S_SET_ALL=false
            S_SET_CORE_ONLY=true
            ;;
        *)
            echo "Error: Unrecognized option '$key'"
            print_usage
            exit 1
            ;;
    esac
    shift
done

if [ ! -z "${CI_TAG_OVERRIDE}" ]; then
    unset BASE_TAG
    BASE_TAG=${CI_TAG_OVERRIDE:-dev}
    echo "[CI] (INFO) CI_TAG_OVERRIDE is set, using tag: ${BASE_TAG}"
fi

if [ ! -z "${CI_BASENAME_OVERRIDE}" ]; then
    unset BASE_IMAGE_NAME
    BASE_IMAGE_NAME=${CI_BASENAME_OVERRIDE:-webcontainer}
    echo "[CI] (INFO) CI_BASENAME_OVERRIDE is set, using name: ${BASE_IMAGE_NAME}"
fi

if [ ! -z "${CI_CORE_CONTAINER}" ]; then
    unset BASE_CORE_IMAGE
    BASE_CORE_IMAGE=${CI_CORE_CONTAINER}
    echo "[CI] (INFO) CI_CORE_CONTAINER is set, using core image: ${BASE_CORE_IMAGE}"
fi

function build_image() {
    local image_name=$1
    local dockerfile_path=$2
    local context_path=$3
    local is_core=$4

    if [ -z "${is_core}" ]; then
        is_core=true
    fi

    echo "is_core: ${is_core} ($4)"

    local build_args=""
    if [[ "${is_core}" = false ]]; then
        echo "[INFO] IsCore is false!"
        if [ ! -z "${BASE_CORE_IMAGE}" ]; then
            echo "[CI] (INFO) BASE_CORE_IMAGE is set, using core image: ${BASE_CORE_IMAGE}"
            build_args="--build-arg BASE_IMAGE=${BASE_CORE_IMAGE}"
        else
            echo "[INFO] Using default core image: ${BASE_IMAGE_NAME}:core-${BASE_TAG}"
            build_args="--build-arg BASE_IMAGE=${BASE_IMAGE_NAME}:core-${BASE_TAG}"
        fi
    fi
    
    echo "Building image ${image_name} using Dockerfile at ${dockerfile_path}..."
    docker build ${build_args} -t ${image_name} -f ${dockerfile_path} ${context_path}
}

if [[ "$S_SET_ALL" = true ]] || [[ "$S_SET_CORE_ONLY" = true ]]; then
    echo "Building Core Image..."
    docker rmi -f "${BASE_IMAGE_NAME}:core-${BASE_TAG}" || true
    build_image "${BASE_IMAGE_NAME}:core-${BASE_TAG}" "${ROOT_DIR}/Dockerfile" "${ROOT_DIR}" true
fi

if [[ "$S_SET_ALL" = true ]] || [[ "$S_SET_NGINX_ONLY" = true ]]; then
    echo "Building Nginx Image..."
    docker rmi -f "${BASE_IMAGE_NAME}:nginx-${BASE_TAG}" || true
    build_image "${BASE_IMAGE_NAME}:nginx-${BASE_TAG}" "${ROOT_DIR}/nginx-build/Dockerfile" "${ROOT_DIR}/nginx-build" false
fi

if [[ "$S_SET_ALL" = true ]] || [[ "$S_SET_OPENRESTY_ONLY" = true ]]; then
    echo "Building Openresty Image..."
    docker rmi -f "${BASE_IMAGE_NAME}:openresty-${BASE_TAG}" || true
    build_image "${BASE_IMAGE_NAME}:openresty-${BASE_TAG}" "${ROOT_DIR}/openresty-build/Dockerfile" "${ROOT_DIR}/openresty-build" false
fi

if [[ "$S_SET_ALL" = true ]] || [[ "$S_SET_CADDY_ONLY" = true ]]; then
    echo "Building Caddy Image..."
    docker rmi -f "${BASE_IMAGE_NAME}:caddy-${BASE_TAG}" || true
    build_image "${BASE_IMAGE_NAME}:caddy-${BASE_TAG}" "${ROOT_DIR}/caddy-build/Dockerfile" "${ROOT_DIR}/caddy-build" false
fi

docker builder prune -a -f