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
RUN apk add git -y && \
git clone https://github.com/akile-network/akile_monitor_fe.git amf && \
cd amf && \
npm install && \
npm run build

FROM caddy:latest AS server
WORKDIR /app
COPY --from=gobuild /build/akile_monitor /app/ak_monitor
COPY --from=gobuild /build/config.json /app/config.json

COPY --from=nodebuild /build/amf/dist /usr/share/caddy
RUN cat <<EOF > /app/entrypoint.sh
#!/bin/sh
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
/app/ak_monitor
EOF

RUN chmod +x /app/entrypoint.sh /app/ak_monitor

EXPOSE 80 3000

CMD ["/app/entrypoint.sh"]

FROM alpine AS client
WORKDIR /app

COPY --from=gobuild /build/client/client /app/ak_client
COPY --from=gobuild /build/client.json /app/client.json

RUN chmod +x /app/ak_client

CMD ["/app/ak_client"]