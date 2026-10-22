#!/usr/bin/env bash
set -euo pipefail

# Built from source: openresty.org's apt repo key is SHA-1 self-signed and rejected by trixie's apt (sequoia).
# Nothing is pinned: every build takes the newest signed OpenResty release (LuaJIT is bundled with it), the newest
# signed LuaRocks release and the newest rocks. Signatures are checked against the vendored keys:
# openresty-release-key.asc (Yichun Zhang, A0E98066) and luarocks-release-key.asc (Hisham Muhammad, 2BB3C478).
# OPENRESTY_MIN is a security floor, not a pin. While no signed release reaches it, the build falls back to the
# newest commit of github.com/openresty/openresty, packaged with their own util/mirror-tarballs.
# ponytail: that fallback is unsigned and mirror-tarballs fetches ~45 component tarballs without checksums;
# it stops being used by itself once a signed release >= OPENRESTY_MIN is published.
# 1.31.7.1 (nginx 1.31.7 core) fixes CVE-2026-42055, -48142, -42533, -56434, -60005, -90439, -15176, -95101,
# -97205 and -97629.
OPENRESTY_MIN="1.31.7.1"
BUILD_DEPS="build-essential libpcre2-dev libssl-dev zlib1g-dev patch dos2unix"
OR_PREFIX="/usr/local/openresty"
LUAJIT="${OR_PREFIX}/luajit"

# newest <version> of "<name>-<version>.tar.gz" links on a release listing page (rc/beta names don't match)
latest_release() {
    curl -fsSL "$2" | grep -oE "$1-[0-9]+(\.[0-9]+)+\.tar\.gz" | sed -E "s/^$1-|\.tar\.gz$//g" | sort -uV | tail -1
}

# verify_sig <key.asc> <file>: <file>.asc must be a valid signature by that key
verify_sig() {
    GNUPGHOME="$(mktemp -d)" bash -c 'gpg --batch -q --import "$1" && gpg --batch --verify "$2.asc" "$2"' _ "$1" "$2"
}

WORK_DIR="$(mktemp -d)"
cd "${WORK_DIR}"

apt-get update
apt-get install -y --no-install-recommends ${BUILD_DEPS} perl make unzip

release="$(latest_release openresty https://openresty.org/en/download.html)"
[ -n "${release}" ] || { echo "[ERROR] could not find the newest OpenResty release"; exit 1; }
if dpkg --compare-versions "${release}" ge "${OPENRESTY_MIN}"; then
    OPENRESTY_VER="${release}"
    echo "[INFO] Building OpenResty ${OPENRESTY_VER} (newest signed release)"
    curl -fsSLO "https://openresty.org/download/openresty-${OPENRESTY_VER}.tar.gz"
    curl -fsSLO "https://openresty.org/download/openresty-${OPENRESTY_VER}.tar.gz.asc"
    verify_sig /openresty-release-key.asc "openresty-${OPENRESTY_VER}.tar.gz"
    tar -zxf "openresty-${OPENRESTY_VER}.tar.gz"
else
    git init -q openresty-src
    git -C openresty-src fetch -q --depth 1 https://github.com/openresty/openresty.git master
    git -C openresty-src checkout -q FETCH_HEAD
    OPENRESTY_VER="$(cd openresty-src && ./util/ver)"
    commit="$(git -C openresty-src rev-parse HEAD)"
    if ! dpkg --compare-versions "${OPENRESTY_VER}" ge "${OPENRESTY_MIN}"; then
        echo "[ERROR] neither the newest release (${release}) nor openresty master (${OPENRESTY_VER}) reaches ${OPENRESTY_MIN} (security floor)"
        exit 1
    fi
    echo "[WARN] Newest signed OpenResty release ${release} is below the security floor ${OPENRESTY_MIN}; building unreleased OpenResty ${OPENRESTY_VER} from openresty/openresty@${commit}"
    make -C openresty-src > mirror-tarballs.log 2>&1 || { tail -50 mirror-tarballs.log; echo "[ERROR] OpenResty mirror-tarballs failed"; exit 1; }
    tar -zxf "openresty-src/openresty-${OPENRESTY_VER}.tar.gz"
fi
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

LUAROCK_VER="$(latest_release luarocks https://luarocks.org/releases/)"
[ -n "${LUAROCK_VER}" ] || { echo "[ERROR] could not find the newest LuaRocks release"; exit 1; }
echo "[INFO] Installing LuaRocks ${LUAROCK_VER} (newest signed release) against OpenResty's LuaJIT"
curl -fsSLO "https://luarocks.org/releases/luarocks-${LUAROCK_VER}.tar.gz"
curl -fsSLO "https://luarocks.org/releases/luarocks-${LUAROCK_VER}.tar.gz.asc"
verify_sig /luarocks-release-key.asc "luarocks-${LUAROCK_VER}.tar.gz"
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
