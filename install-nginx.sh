#!/bin/bash

if [ "$USE_VAULT" = true ]; then
    # Install vault client
    wget -q https://releases.hashicorp.com/vault/0.5.2/vault_0.5.2_linux_amd64.zip && \
    unzip -d /usr/local/bin vault_0.5.2_linux_amd64.zip && \
    ./etc/ssl/nginx/vault_env.sh && \
    mkdir -p /etc/ssl/nginx && \
    vault token-renew
    # Download certificate and key from the the vault and copy to the build context
    vault read -field=value secret/ssl/certificate.pem > /etc/ssl/nginx/certificate.pem
    vault read -field=value secret/ssl/key.pem > /etc/ssl/nginx/key.pem
    vault read -field=value secret/ssl/dhparam.pem > /etc/ssl/nginx/dhparam.pem

    if [ "$USE_NGINX_PLUS" = true ]; then
        vault read -field=value secret/nginx-repo.crt > /etc/ssl/nginx/nginx-repo.crt
        vault read -field=value secret/nginx-repo.key > /etc/ssl/nginx/nginx-repo.key
        vault read -field=value secret/ssl/csr.pem > /etc/ssl/nginx/csr.pem
    fi
fi

# ensure certificate files exist
if [[ ! -f /etc/ssl/nginx/certificate.pem || ! -f /etc/ssl/nginx/key.pem ]]; then
    echo -e "\033[31m -----"
    echo -e "\033[31m The certificate.pem or key.pem file does not exist in /etc/ssl/nginx"
    echo -e "\033[31m These files should copied by the COPY command in Dockerfile when USE_VAULT is false."
    echo -e "\033[31m If you are using vault, be sure that USE_VAULT is true in the Dockerfile."
    echo -e "\033[31m Generating self-signed certificates instead."
    echo -e "\033[31m -----\033[0m"
    openssl req -nodes -newkey rsa:2048 -keyout /etc/ssl/nginx/key.pem -out /etc/ssl/nginx/csr.pem -subj \
        "/C=US/ST=California/L=San Francisco/O=NGINX/OU=Professional Services/CN=proxy"
    openssl x509 -req -days 365 -in /etc/ssl/nginx/csr.pem -signkey /etc/ssl/nginx/key.pem -out /etc/ssl/nginx/certificate.pem
fi

if [ "$USE_NGINX_PLUS" = true ]; then
    echo "Installing NGINX Plus"

    if [[ ! -f /etc/ssl/nginx/nginx-repo.crt && ! -f /etc/ssl/nginx/nginx-repo.key ]]; then
        echo -e "\033[31m -----"
        echo -e "\033[31m The nginx-repo.crt and nginx-repo.key files were not found in /etc/ssl/nginx"
        echo -e "\033[31m These file should copied by the COPY command in Dockerfile when USE_VAULT is false."
        echo -e "\033[31m If you have implemented vault, be sure that USE_VAULT is true in the Dockerfile."
        echo -e "\033[31m -----\033[0m"
        exit 1;
    fi

    wget -q -O /etc/ssl/nginx/CA.crt https://cs.nginx.com/static/files/CA.crt
    wget -q -O - http://nginx.org/keys/nginx_signing.key | apt-key add -
    wget -q -O /etc/apt/apt.conf.d/90nginx https://cs.nginx.com/static/files/90nginx
    printf "deb https://plus-pkgs.nginx.com/`lsb_release -is | awk '{print tolower($0)}'` `lsb_release -cs` nginx-plus\n" >/etc/apt/sources.list.d/nginx-plus.list

    # Install NGINX Plus
    apt-get update
    apt-get install -o Dpkg::Options::="--force-confold" -y nginx-plus
else
    echo "Installing NGINX OSS"

    wget -q -O - http://nginx.org/keys/nginx_signing.key | apt-key add -
    printf "deb http://nginx.org/packages/`lsb_release -is | awk '{print tolower($0)}'`/ `lsb_release -cs` nginx\n" >/etc/apt/sources.list.d/nginx.list

    apt-get update
    apt-get install -o Dpkg::Options::="--force-confold" -y nginx
fi

sh /etc/nginx/generate-nginx-config.sh
sh /etc/nginx/generate-custom-nginx-config.sh
