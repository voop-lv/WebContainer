#!/usr/bin/env bash

apt-get update
apt-get full-upgrade -y

apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list
apt-get update

apt-get install -y caddy

echo "Configuring Clean Install and Default Configuration!"

echo "Copying Supervisor 1_pack.conf"
cp -r -f -v /temp_config/supervisord/1_pack.conf /vl/supervisord/1_pack.conf
rm -rf /temp_config/supervisord/1_pack.conf

echo "Updating Clean Install Dir"
cp -r -f -v /temp_config/* /clean/config