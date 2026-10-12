#!/usr/bin/env bash

# CVE-2026-42945, CVE-2026-42946, CVE-2026-40701, CVE-2026-42934 — upgrade to nginx 1.30.1+
echo "Adding official nginx.org stable repository (nginx 1.30.1+)"

apt-get update
apt-get install -y curl gnupg lsb-release

curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/debian $(lsb_release -sc) nginx" > /etc/apt/sources.list.d/nginx.list
printf "Package: *\nPin: origin nginx.org\nPin-Priority: 900\n" > /etc/apt/preferences.d/99nginx

echo "Installing Nginx!"

apt-get update
apt-get full-upgrade -y

apt-get install nginx -y

echo "Configuring Clean Install and Default Configuration!"

echo "Updating Clean Install Dir"
cp -r -f -v /temp_config/* /clean/config

echo "Updating Config Dir"
cp -r -f -v /temp_config/* /config/

echo "=== End of script ==="