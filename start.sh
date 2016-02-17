#!/bin/bash

uwsgi --ini uwsgi.ini
service amplify-agent start
nginx