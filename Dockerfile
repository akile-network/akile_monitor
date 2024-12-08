FROM golang:alpine AS gobuild
WORKDIR /build
COPY . /build
RUN go mod download && \
go mod tidy && \
go mod verify && \
go build
RUN cd client && \
go mod download && \
go mod tidy && \
go mod verify && \
go build

FROM node:lts-alpine AS nodebuild
WORKDIR /build
RUN apk add git && \
git clone https://github.com/akile-network/akile_monitor_fe.git amf && \
cd amf && \
npm install && \
npm run build && \
rm -rf dist/config.json

FROM alpine AS server
WORKDIR /app

ENV AUTH_SECRET=${AUTH_SECRET:-auth_secret}
ENV LISTEN=${LISTEN:-:3000}
ENV ENABLE_TG=${ENABLE_TG:-false}
ENV TG_TOKEN=${TG_TOKEN:-your_telegram_bot_token}
ENV HOOK_URI=${HOOK_URI:-/hook}
ENV UPDATE_URI=${UPDATE_URI:-/monitor}
ENV WEB_URI=${WEB_URI:-/ws}
ENV HOOK_TOKEN=${HOOK_TOKEN:-hook_token}
ENV TG_CHAT_ID=${TG_CHAT_ID:-0}

COPY --from=gobuild /build/akile_monitor /app/ak_monitor

RUN cat <<'EOF' > entrypoint.sh
#!/bin/sh
if [ ! -f "config.json" ]; then
    echo "{
  \"auth_secret\": \"${AUTH_SECRET}\",
  \"listen\": \"${LISTEN}\",
  \"enable_tg\": ${ENABLE_TG},
  \"tg_token\": \"${TG_TOKEN}\",
  \"hook_uri\": \"${HOOK_URI}\",
  \"update_uri\": \"${UPDATE_URI}\",
  \"web_uri\": \"${WEB_URI}\",
  \"hook_token\": \"${HOOK_TOKEN}\",
  \"tg_chat_id\": ${TG_CHAT_ID}
}"> config.json
fi
/app/ak_monitor
EOF

EXPOSE 3000

RUN chmod +x ak_monitor entrypoint.sh
CMD ["./entrypoint.sh"]

FROM caddy:latest AS fe
WORKDIR /app

ENV SOCKET=${SOCKET:-ws://192.168.31.64:3000/ws}
ENV APIURL=${APIURL:-http://192.168.31.64:3000}

COPY --from=nodebuild /build/amf/dist /usr/share/caddy

RUN cat <<'EOF' > entrypoint.sh
#!/bin/sh
if [ ! -f "/usr/share/caddy/config.json" ]; then
    echo "{
  \"socket\": \"${SOCKET}\",
  \"apiURL\": \"${APIURL}\"
}"> /usr/share/caddy/config.json
fi
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
EOF

EXPOSE 80

RUN chmod +x entrypoint.sh
CMD ["./entrypoint.sh"]

FROM alpine AS client
WORKDIR /app

ENV AUTH_SECRET=${AUTH_SECRET:-auth_secret}
ENV URL=${URL:-ws://localhost:3000/monitor}
ENV NET_NAME=${NET_NAME:-eth0}
ENV NAME=${NAME:-HK-Akile}

COPY --from=gobuild /build/client/client /app/ak_client

RUN cat <<'EOF' > entrypoint.sh
#!/bin/sh
if [ ! -f "client.json" ]; then
    echo "{
  \"auth_secret\": \"${AUTH_SECRET}\",
  \"url\": \"${URL}\",
  \"net_name\": \"${NET_NAME}\",
  \"name\": \"${NAME}\"
}"> client.json
fi
/app/ak_client
EOF

RUN chmod +x ak_client entrypoint.sh
CMD ["./entrypoint.sh"]