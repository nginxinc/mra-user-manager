#!/usr/bin/env bash

wget -O /usr/local/sbin/generate_config -q https://s3-us-west-1.amazonaws.com/fabric-model/config-generator/generate_config
chmod +x /usr/local/sbin/generate_config

FABRIC_TEMPLATE_FILE="/etc/nginx/fabric/fabric_nginx-plus.conf.j2"

if [ "$USE_NGINX_PLUS" = false ];
then
    FABRIC_TEMPLATE_FILE="/etc/nginx/fabric/fabric_nginx.conf.j2"
fi

echo Generating NGINX configurations...

# Generate configurations for Fabric Model
/usr/local/sbin/generate_config -p /etc/nginx/fabric/fabric_config_dcos.yaml -t ${FABRIC_TEMPLATE_FILE} > /etc/nginx/fabric_nginx_dcos.conf
/usr/local/sbin/generate_config -p /etc/nginx/fabric/fabric_config_k8s.yaml -t ${FABRIC_TEMPLATE_FILE} > /etc/nginx/fabric_nginx_kubernetes.conf
/usr/local/sbin/generate_config -p /etc/nginx/fabric/fabric_config_local.yaml -t ${FABRIC_TEMPLATE_FILE} > /etc/nginx/fabric_nginx_local.conf
