#!/bin/sh
NGINX_PID="/var/run/nginx.pid"    # /   (root directory)
APP="uwsgi --ini uwsgi.ini"

if [ "$DEV_MODE" = "true" ]
then
    APP="$APP --py-autoreload 5"
fi

# start the application using UWSGI
$APP 

nginx -c "/etc/nginx/nginx.conf" -g "pid $NGINX_PID;"

sleep 30
APP_PID=`ps aux | grep $APP | grep -v grep`

while [ -f "$NGINX_PID" ] &&  [ "$APP_PID" ];
do 
	sleep 5;
	APP_PID=`ps aux | grep $APP | grep -v grep`;
done
