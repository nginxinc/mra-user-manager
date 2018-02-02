#!/bin/sh
NGINX_PID="/var/run/nginx.pid"    # /   (root directory)
APP="uwsgi --ini uwsgi.ini"
DEBUG=""

if [ "$DEV_MODE" = "true" ]
then
    DEBUG=" --py-autoreload 5"
fi

# start the application using UWSGI
$APP $DEBUG

nginx -c "/etc/nginx/nginx.conf" -g "pid $NGINX_PID;"

sleep 30
APP_PID=`ps aux | grep $APP | grep -v grep`

while [ -f "$NGINX_PID" ] &&  [ "$APP_PID" ];
do 
	sleep 5;
	APP_PID=`ps aux | grep $APP | grep -v grep`;
done
