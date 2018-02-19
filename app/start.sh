#!/bin/sh
APP="uwsgi --ini uwsgi.ini"
DEBUG=""

if [ "$DEV_MODE" = "true" ]
then
    DEBUG=" --py-autoreload 5"
fi

if [ "$NETWORK" = "fabric" ]
then
	NGINX_PID="/var/run/nginx.pid"    # /   (root directory)
	nginx -c "/etc/nginx/nginx.conf" -g "pid $NGINX_PID;"
fi

# start the application using UWSGI
$APP $DEBUG

sleep 30
APP_PID=`ps aux | grep $APP | grep -v grep`

if [ "$NETWORK" = "fabric" ]
then
	while [ -f "$NGINX_PID" ] &&  [ "$APP_PID" ];
	do
		sleep 5;
		APP_PID=`ps aux | grep $APP | grep -v grep`;
	done
else
	while [ "$APP_PID" ];
	do
		sleep 5;
		APP_PID=`ps aux | grep $APP | grep -v grep`;
	done
fi