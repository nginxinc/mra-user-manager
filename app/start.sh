#!/bin/sh
NGINX_PID="/var/run/nginx.pid"    # /   (root directory)
APP="uwsgi --ini uwsgi.ini"

NGINX_CONF="/etc/nginx/nginx.conf";

if [ "$NETWORK" = "fabric" ]
then
    echo fabric configuration set;
fi

$APP 

nginx -c "$NGINX_CONF" -g "pid $NGINX_PID;"

sleep 30
APP_PID=`ps aux | grep $APP | grep -v grep`

while [ -f "$NGINX_PID" ] &&  [ "$APP_PID" ];
do 
	sleep 5;
	APP_PID=`ps aux | grep $APP | grep -v grep`;
done
