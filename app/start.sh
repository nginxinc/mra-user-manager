#!/bin/sh
NGINX_PID="/var/run/nginx.pid"    # /   (root directory)
NGINX_CONF=""
APP="uwsgi --ini uwsgi.ini"
DEBUG=""

case "$NETWORK" in
    fabric)
        NGINX_CONF="/etc/nginx/fabric_nginx_$CONTAINER_ENGINE.conf"
        echo 'Fabric configuration set'
        nginx -c "$NGINX_CONF" -g "pid $NGINX_PID;" &
        ;;
    router-mesh)
        ;;
    *)
        echo 'Network not supported'
esac

if [ "$DEV_MODE" = "true" ]
then
    DEBUG=" --py-autoreload 5"
fi

# start the application using UWSGI
$APP $DEBUG

sleep 30
APP_PID=`ps aux | grep $APP | grep -v grep`

while [ -f "$NGINX_PID" ] &&  [ "$APP_PID" ];
do 
	sleep 5;
	APP_PID=`ps aux | grep $APP | grep -v grep`;
done
