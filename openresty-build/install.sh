#!/usr/bin/env bash
set -euo pipefail

# Built from source: openresty.org's apt repo key is SHA-1 self-signed and rejected by trixie's apt (sequoia).
# 1.31.7.1 (nginx 1.31.7 core) fixes CVE-2026-42055, -48142, -42533, -56434, -60005, -90439, -15176, -95101,
# -97205 and -97629; no signed release carries those yet (newest is 1.31.1.1), so the tarball is generated from
# OpenResty's repo at a pinned commit with their own util/mirror-tarballs, as their release process does.
# ponytail: the repo is pinned by commit SHA, but mirror-tarballs fetches ~45 component tarballs from GitHub
# without checksums. Go back to the signed tarball (gpg-verified against the vendored openresty-release-key.asc,
# key A0E98066) as soon as 1.31.7.x is published at openresty.org/download.
OPENRESTY_VER="1.31.7.1"
OPENRESTY_COMMIT="730f20bab89e5f22072b09dd3a859ad7571b734d"
LUAROCK_VER="3.12.2"
LUAROCK_SHA256="b0e0c85205841ddd7be485f53d6125766d18a81d226588d2366931e9a1484492"
BUILD_DEPS="build-essential libpcre2-dev libssl-dev zlib1g-dev patch dos2unix"
OR_PREFIX="/usr/local/openresty"
LUAJIT="${OR_PREFIX}/luajit"

WORK_DIR="$(mktemp -d)"
cd "${WORK_DIR}"

apt-get update
apt-get install -y --no-install-recommends ${BUILD_DEPS} perl make unzip

echo "[INFO] Generating OpenResty ${OPENRESTY_VER} source tarball from commit ${OPENRESTY_COMMIT}"
git init -q openresty-src
git -C openresty-src fetch -q --depth 1 https://github.com/openresty/openresty.git "${OPENRESTY_COMMIT}"
git -C openresty-src checkout -q FETCH_HEAD
[ "$(git -C openresty-src rev-parse HEAD)" = "${OPENRESTY_COMMIT}" ] || { echo "[ERROR] OpenResty checkout is not ${OPENRESTY_COMMIT}"; exit 1; }
repo_ver="$(cd openresty-src && ./util/ver)"
[ "${repo_ver}" = "${OPENRESTY_VER}" ] || { echo "[ERROR] commit ${OPENRESTY_COMMIT} is OpenResty ${repo_ver}, expected ${OPENRESTY_VER}"; exit 1; }
make -C openresty-src > mirror-tarballs.log 2>&1 || { tail -50 mirror-tarballs.log; echo "[ERROR] OpenResty mirror-tarballs failed"; exit 1; }
tar -zxf "openresty-src/openresty-${OPENRESTY_VER}.tar.gz"
cd "openresty-${OPENRESTY_VER}"
# Same module set as the official openresty .deb so existing configs (aio threads, sub_filter, ...) keep working.
./configure -j"$(nproc)" \
    --with-pcre-jit --with-threads --with-file-aio --with-compat \
    --with-http_ssl_module --with-http_v2_module --with-http_v3_module \
    --with-http_realip_module --with-http_stub_status_module \
    --with-http_gzip_static_module --with-http_gunzip_module \
    --with-http_addition_module --with-http_auth_request_module \
    --with-http_secure_link_module --with-http_random_index_module \
    --with-http_sub_module --with-http_dav_module \
    --with-http_flv_module --with-http_mp4_module --with-http_slice_module \
    --with-stream --with-stream_ssl_module --with-stream_ssl_preread_module \
    --without-mail_pop3_module --without-mail_imap_module --without-mail_smtp_module
make -j"$(nproc)"
make install
# restydoc's bundled docs include sample private keys that trip secret scanners; not needed in a container.
rm -rf "${OR_PREFIX}/pod" "${OR_PREFIX}/bin/restydoc" "${OR_PREFIX}/bin/restydoc-index" "${OR_PREFIX}/bin/md2pod.pl" "${OR_PREFIX}/bin/nginx-xml2pod"
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
