#!/usr/bin/env bash

BASE_LUA="5.4"
LUA_VER="${BASE_LUA}.8"
LUAROCK_VER="3.12.2"
CURRECT_DIR=$(pwd)

apt-get update
apt-get install libpcre3-dev libssl-dev perl make build-essential curl wget gnupg ca-certificates libreadline-dev unzip -y

echo "Installing LUA ($LUA_VER) and LuaRock ($LUAROCK_VER)"
curl -R -O https://www.lua.org/ftp/lua-${LUA_VER}.tar.gz
tar -zxf lua-${LUA_VER}.tar.gz
rm lua-${LUA_VER}.tar.gz
cd lua-${LUA_VER}
make linux test
make install
cd ${CURRECT_DIR}

export PATH=$PATH:/usr/local/bin

wget https://luarocks.org/releases/luarocks-${LUAROCK_VER}.tar.gz
tar zxpf luarocks-${LUAROCK_VER}.tar.gz
rm luarocks-${LUAROCK_VER}.tar.gz
cd luarocks-${LUAROCK_VER}
./configure --lua-version=${BASE_LUA} --with-lua-include=/usr/local/include
make install
cd ${CURRECT_DIR}

rm -rf lua-${LUA_VER}
rm -rf luarocks-${LUAROCK_VER}

echo "Pre-installing Lua Libs"

luarocks install lua-resty-openidc
luarocks install lua-resty-http
luarocks install lua-cjson

echo "Installing Openresty"
wget -O - https://openresty.org/package/pubkey.gpg | apt-key add -
codename=`grep -Po 'VERSION="[0-9]+ \(\K[^)]+' /etc/os-release`

echo "deb http://openresty.org/package/debian $codename openresty" \
    | tee /etc/apt/sources.list.d/openresty.list
apt-get update    
echo "Installing openresty!"

apt-get -y install openresty

echo "Configuring Clean Install and Default Configuration!"

echo "Copying Supervisor 1_pack.conf"
cp -r -f -v /temp_config/supervisord/1_pack.conf /vl/supervisord/1_pack.conf
rm -rf /temp_config/supervisord/1_pack.conf

echo "Updating Clean Install Dir"
cp -r -f -v /temp_config/* /clean/config
cp -r -f -v /temp_scripts/* /clean/scripts

echo "Updating Config Dir"
cp -r -f -v /temp_config/* /config

echo "Updating Default page"
mkdir /usr/local/openresty/nginx/html
cp -r -f -v /clean/config/defaults/page/webdata/* /usr/local/openresty/nginx/html
chmod 777 -R /usr/local/openresty/nginx/html/*

