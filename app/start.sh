#!/bin/sh
NGINX_PID="/var/run/nginx.pid"    # /   (root directory)
NGINX_CONF=""
APP="uwsgi --ini uwsgi.ini"
DEBUG=""

if [ "$DEV_MODE" = "true" ]
then
    DEBUG=" --py-autoreload 5"
fi

# start the application using UWSGI
${APP} ${DEBUG} &

sleep 30
APP_PID=`ps aux | grep ${APP} | grep -v grep`

case "$NETWORK" in
    fabric)
        NGINX_CONF="/etc/nginx/fabric_nginx_$CONTAINER_ENGINE.conf"
        echo 'Fabric configuration set'
        nginx -c "$NGINX_CONF" -g "pid $NGINX_PID;" &

        sleep 10

        while [ -f "$NGINX_PID" ] &&  [ "$APP_PID" ];
        do
	        sleep 5;
	        APP_PID=`ps aux | grep ${APP} | grep -v grep`;
        done
        ;;
    router-mesh)
        while [ "$APP_PID" ];
        do
	        sleep 5;
	        APP_PID=`ps aux | grep ${APP} | grep -v grep`;
        done
        ;;
    proxy)
        while [ "$APP_PID" ];
        do
	        sleep 5;
	        APP_PID=`ps aux | grep ${APP} | grep -v grep`;
        done
        ;;
    *)
        echo 'Network not supported'
        exit 1
esac
