#!/bin/bash

export NEW_RELIC_CONFIG_FILE=newrelic.ini

newrelic-admin run-program uwsgi --ini uwsgi.ini
service amplify-agent start
nginx
