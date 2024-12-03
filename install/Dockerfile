FROM nginx:bookworm

EXPOSE 80

RUN apt update && apt install -y wget curl systemd supervisor xz-utils git && rm -rf /var/lib/apt/lists/*

RUN cd /usr/local/lib && wget https://nodejs.org/dist/v22.11.0/node-v22.11.0-linux-x64.tar.xz && tar -xvf node-v22.11.0-linux-x64.tar.xz && rm node-v22.11.0-linux-x64.tar.xz && ln -s /usr/local/lib/node-v22.11.0-linux-x64/bin/node /usr/local/bin/node && ln -s /usr/local/lib/node-v22.11.0-linux-x64/bin/npm /usr/local/bin/npm && ln -s /usr/local/lib/node-v22.11.0-linux-x64/bin/npx /usr/local/bin/npx && cd && mkdir -p /usr/share/nginx/html
    
RUN wget -O /init.sh https://raw.githubusercontent.com/miaowmint/akile_monitor/refs/heads/main/init.sh && chmod +x /init.sh

CMD ["/init.sh"]
