#!/bin/bash

wget -O /usr/local/sbin/generate_config -q https://s3-us-west-1.amazonaws.com/fabric-model/config-generator/generate_config
chmod +x /usr/local/sbin/generate_config
. /etc/letsencrypt/vault_env.sh

# Download certificate and key from the the vault and copy to the build context
vault token-renew
vault read -field=value secret/ssl/certificate.pem > /etc/ssl/nginx/certificate.pem
vault read -field=value secret/ssl/key.pem > /etc/ssl/nginx/key.pem
vault read -field=value secret/ssl/dhparam.pem > /etc/ssl/nginx/dhparam.pem

if [ "$USE_NGINX_PLUS" = true ];
then
  echo "Installing NGINX Plus"
    vault read -field=value secret/nginx-repo.crt > /etc/ssl/nginx/nginx-repo.crt
    vault read -field=value secret/nginx-repo.key > /etc/ssl/nginx/nginx-repo.key
    vault read -field=value secret/ssl/csr.pem > /etc/ssl/nginx/csr.pem

  wget -q -O /etc/ssl/nginx/CA.crt https://cs.nginx.com/static/files/CA.crt
  wget -q -O - http://nginx.org/keys/nginx_signing.key | apt-key add -
  wget -q -O /etc/apt/apt.conf.d/90nginx https://cs.nginx.com/static/files/90nginx
  printf "deb https://plus-pkgs.nginx.com/`lsb_release -is | awk '{print tolower($0)}'` `lsb_release -cs` nginx-plus\n" >/etc/apt/sources.list.d/nginx-plus.list

  # Install NGINX Plus
  apt-get update
  apt-get install -o Dpkg::Options::="--force-confold" -y nginx-plus

  /usr/local/sbin/generate_config -p /etc/nginx/fabric_config.yaml -t /etc/nginx/nginx-plus-fabric.conf.j2 > /etc/nginx/nginx.conf
else
  echo "Installing NGINX OSS"

  wget -q -O - http://nginx.org/keys/nginx_signing.key | apt-key add -
  printf "deb http://nginx.org/packages/`lsb_release -is | awk '{print tolower($0)}'`/ `lsb_release -cs` nginx\n" >/etc/apt/sources.list.d/nginx.list

  apt-get update
  apt-get install -o Dpkg::Options::="--force-confold" -y nginx

    /usr/local/sbin/generate_config -p /etc/nginx/fabric_config.yaml -t /etc/nginx/nginx-fabric.conf.j2 > /etc/nginx/nginx.conf
fi
