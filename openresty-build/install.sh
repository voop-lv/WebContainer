#!/usr/bin/env bash
set -euo pipefail

# >= 1.29.2.4 carries the backported fix for CVE-2026-42945 (nginx rewrite heap overflow).
# Built from source: openresty.org's apt repo key is SHA-1 self-signed and rejected by trixie's apt (sequoia).
# Tarballs are signed by Yichun Zhang's key A0E98066 (vendored as openresty-release-key.asc).
OPENRESTY_VER="1.29.2.5"
OPENRESTY_SHA256="3195e665c97023419051dc51d195e9f774a3d00ed6e7cd8a3751c4722ea0a8c1"
LUAROCK_VER="3.12.2"
LUAROCK_SHA256="b0e0c85205841ddd7be485f53d6125766d18a81d226588d2366931e9a1484492"
BUILD_DEPS="build-essential libpcre2-dev libssl-dev zlib1g-dev"
OR_PREFIX="/usr/local/openresty"
LUAJIT="${OR_PREFIX}/luajit"

WORK_DIR="$(mktemp -d)"
cd "${WORK_DIR}"

apt-get update
apt-get install -y --no-install-recommends ${BUILD_DEPS} perl make unzip

echo "[INFO] Building OpenResty ${OPENRESTY_VER} from source"
curl -fsSLO "https://openresty.org/download/openresty-${OPENRESTY_VER}.tar.gz"
curl -fsSLO "https://openresty.org/download/openresty-${OPENRESTY_VER}.tar.gz.asc"
echo "${OPENRESTY_SHA256}  openresty-${OPENRESTY_VER}.tar.gz" | sha256sum -c -
GNUPGHOME="$(mktemp -d)" bash -c "gpg --batch --import /openresty-release-key.asc && gpg --batch --verify openresty-${OPENRESTY_VER}.tar.gz.asc openresty-${OPENRESTY_VER}.tar.gz"
tar -zxf "openresty-${OPENRESTY_VER}.tar.gz"
cd "openresty-${OPENRESTY_VER}"
./configure -j"$(nproc)" \
    --with-pcre-jit \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_stub_status_module \
    --with-http_gzip_static_module \
    --with-stream \
    --with-stream_ssl_module
make -j"$(nproc)"
make install
ln -sf "${OR_PREFIX}/bin/openresty" /usr/local/bin/openresty
ln -sf "${OR_PREFIX}/bin/resty" /usr/local/bin/resty
ln -sf "${LUAJIT}/bin/luajit" /usr/local/bin/luajit
cd "${WORK_DIR}"

installed="$(openresty -v 2>&1 | grep -oP 'openresty/\K[0-9.]+')"
echo "[INFO] OpenResty ${installed} installed"
[ "${installed}" = "${OPENRESTY_VER}" ] || { echo "[ERROR] expected OpenResty ${OPENRESTY_VER}, got ${installed}"; exit 1; }

echo "[INFO] Installing LuaRocks ${LUAROCK_VER} against OpenResty's LuaJIT"
curl -fsSLO "https://luarocks.org/releases/luarocks-${LUAROCK_VER}.tar.gz"
echo "${LUAROCK_SHA256}  luarocks-${LUAROCK_VER}.tar.gz" | sha256sum -c -
tar -zxf "luarocks-${LUAROCK_VER}.tar.gz"
cd "luarocks-${LUAROCK_VER}"
./configure --prefix="${LUAJIT}" \
    --with-lua="${LUAJIT}" \
    --with-lua-interpreter=luajit \
    --with-lua-include="${LUAJIT}/include/luajit-2.1" \
    --lua-version=5.1
make install
ln -sf "${LUAJIT}/bin/luarocks" /usr/local/bin/luarocks
cd "${WORK_DIR}"

echo "[INFO] Pre-installing Lua libs (cjson is bundled with OpenResty)"
luarocks install lua-resty-openidc
luarocks install lua-resty-http
resty -e 'require "resty.openidc"; require "resty.http"; require "cjson"; print("lua libs ok")'

echo "[INFO] Rendering per-PHP-version fastcgi includes"
for v in $(cat /vl/php_versions); do
    sed "s/{PHP_VERSION}/${v}/g" /temp_config/openresty/php_fastcgi.conf > "/temp_config/openresty/php${v//./}_fastcgi.conf"
done
rm /temp_config/openresty/php_fastcgi.conf

echo "[INFO] Installing supervisor pack config"
cp -f /temp_config/supervisord/1_pack.conf /vl/supervisord/1_pack.conf
rm -rf /temp_config/supervisord

echo "[INFO] Updating clean install dir and config dir"
cp -r -f /temp_config/* /clean/config
cp -r -f /temp_config/* /config

echo "[INFO] Updating default page"
mkdir -p "${OR_PREFIX}/nginx/html"
cp -r -f /clean/config/defaults/page/webdata/* "${OR_PREFIX}/nginx/html"

echo "[INFO] Removing build dependencies"
cd /
rm -rf "${WORK_DIR}"
apt-get purge -y --auto-remove ${BUILD_DEPS}
apt-get clean
rm -rf /var/lib/apt/lists/*
echo "=== End of script ==="
