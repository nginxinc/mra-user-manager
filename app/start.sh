#!/bin/sh
APP="uwsgi --ini uwsgi.ini"
DEBUG=""

if [ "$DEV_MODE" = "true" ]
then
    DEBUG=" --py-autoreload 5"
fi

# start the application using UWSGI
$APP $DEBUG

sleep 30
APP_PID=`ps aux | grep $APP | grep -v grep`

while [ "$APP_PID" ];
do 
	sleep 5;
	APP_PID=`ps aux | grep $APP | grep -v grep`;
done
