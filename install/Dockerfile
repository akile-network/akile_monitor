FROM nginx:alpine

EXPOSE 80

RUN apk add --no-cache bash wget curl jq unzip

RUN wget -O /init.sh https://raw.githubusercontent.com/miaowmint/akile_monitor/refs/heads/main/init.sh && chmod +x /init.sh

CMD ["/init.sh"]
