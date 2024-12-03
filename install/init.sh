#!/bin/bash

mkdir -p /usr/share/nginx/html
wget -O /tmp/akile_monitor_fe.zip https://github.com/akile-network/akile_monitor_fe/releases/download/v0.0.1/akile_monitor_fe.zip
unzip -o /tmp/akile_monitor_fe.zip -d /usr/share/nginx/html
rm /tmp/akile_monitor_fe.zip
cd /usr/share/nginx/html

API_URL="${API_URL:-http://192.168.31.64:3000}"
ENABLE_WSS="${ENABLE_WSS:-false}"
SOCKET="${SOCKET:-192.168.31.64:3000}"
WEB_URI="${WEB_URI:-/ws}"

jq --arg apiURL "$API_URL" \
   --arg enableWss "$ENABLE_WSS" \
   --arg socket "$SOCKET" \
   --arg webUri "$WEB_URI" \
   '(.apiURL = $apiURL) |
    (.socket |= (if $enableWss == "true" then sub("^ws://"; "wss://") else . end)) |
    (.socket |= sub("://[^/]+"; "://\($socket)")) |
    (.socket |= sub("/[^/]*$"; "\($webUri)"))' config.json > config_modified.json && mv config_modified.json config.json

cat config.json

nginx -g "daemon off;"
