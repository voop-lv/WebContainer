#!/usr/bin/env bash
set -euo pipefail

BASE_LUA="5.4"
LUA_VER="${BASE_LUA}.8"
LUA_SHA256="4f18ddae154e793e46eeab727c59ef1c0c0c2b744e7b94219710d76f530629ae"
LUAROCK_VER="3.12.2"
LUAROCK_SHA256="b0e0c85205841ddd7be485f53d6125766d18a81d226588d2366931e9a1484492"
# >= 1.29.2.4 carries the backported fix for CVE-2026-42945 (nginx rewrite heap overflow).
# Built from source: openresty.org's apt repo key is SHA-1 self-signed and rejected by trixie's apt (sequoia).
# Tarballs are signed by Yichun Zhang's key A0E98066 (vendored as openresty-release-key.asc).
OPENRESTY_VER="1.29.2.5"
OPENRESTY_SHA256="3195e665c97023419051dc51d195e9f774a3d00ed6e7cd8a3751c4722ea0a8c1"
BUILD_DEPS="build-essential libpcre2-dev libssl-dev zlib1g-dev"

WORK_DIR="$(mktemp -d)"
cd "${WORK_DIR}"

apt-get update
apt-get install -y --no-install-recommends ${BUILD_DEPS} perl make unzip

echo "[INFO] Installing Lua ${LUA_VER} and LuaRocks ${LUAROCK_VER}"
curl -fsSLO "https://www.lua.org/ftp/lua-${LUA_VER}.tar.gz"
echo "${LUA_SHA256}  lua-${LUA_VER}.tar.gz" | sha256sum -c -
tar -zxf "lua-${LUA_VER}.tar.gz"
make -C "lua-${LUA_VER}" linux test
make -C "lua-${LUA_VER}" install

export PATH=$PATH:/usr/local/bin
curl -fsSLO "https://luarocks.org/releases/luarocks-${LUAROCK_VER}.tar.gz"
echo "${LUAROCK_SHA256}  luarocks-${LUAROCK_VER}.tar.gz" | sha256sum -c -
tar -zxf "luarocks-${LUAROCK_VER}.tar.gz"
cd "luarocks-${LUAROCK_VER}"
./configure --lua-version="${BASE_LUA}" --with-lua-include=/usr/local/include
make install
cd "${WORK_DIR}"

echo "[INFO] Pre-installing Lua libs"
luarocks install lua-resty-openidc
luarocks install lua-resty-http
luarocks install lua-cjson

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
ln -sf /usr/local/openresty/bin/openresty /usr/local/bin/openresty
cd "${WORK_DIR}"

installed="$(openresty -v 2>&1 | grep -oP 'openresty/\K[0-9.]+')"
echo "[INFO] OpenResty ${installed} installed"
[ "${installed}" = "${OPENRESTY_VER}" ] || { echo "[ERROR] expected OpenResty ${OPENRESTY_VER}, got ${installed}"; exit 1; }

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
mkdir -p /usr/local/openresty/nginx/html
cp -r -f /clean/config/defaults/page/webdata/* /usr/local/openresty/nginx/html

echo "[INFO] Removing build dependencies"
cd /
rm -rf "${WORK_DIR}"
apt-get purge -y --auto-remove ${BUILD_DEPS}
apt-get clean
rm -rf /var/lib/apt/lists/*
echo "=== End of script ==="
