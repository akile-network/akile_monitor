# Docker 部署介绍

- 将前端[akile_monitor_fe](https://github.com/akile-network/akile_monitor_fe)，主控服务[ak_monitor](https://github.com/akile-network/akile_monitor)以及被控客户端[ak_client](https://github.com/akile-network/akile_monitor)打包进容器，并利用 GitHub Actions 自动构建Docker镜像并推送至Docker Hub
- 前端 端口80 主控服务端 端口3000 可自行映射到宿主机或反向代理TLS加密
- 前端配置文件 主控服务端配置文件 被控客户端配置文件 共三个配置文件需要修改

## 支持架构

- linux/amd64
- linux/arm64

# 准备工作

> *以下所有 `/CHANGE_PATH` 替换为你的宿主机路径, 提前创建以下文件避免Docker自动创建文件夹导致失败*

- [Docker](https://docs.docker.com/get-started/get-docker/) 安装

## 前端

- 前端配置文件 `/CHANGE_PATH/akile_monitor/caddy/config.json` 参考如下
```
{
  "socket": "ws://192.168.31.64:3000/ws",
  "apiURL": "http://192.168.31.64:3000"
}
```

## 主控服务端

- [主控服务端配置文件](https://github.com/akile-network/akile_monitor/blob/main/config.json) `/CHANGE_PATH/akile_monitor/config.json`
- SQLite数据库 `/CHANGE_PATH/akile_monitor/ak_monitor.db`

## 被控客户端

- [被控客户端配置文件](https://github.com/akile-network/akile_monitor/blob/main/client.json) `/CHANGE_PATH/akile_monitor/client.json`

# [compose文件](./docker-compose.yml)

# 主控服务端

## Docker Cli 部署

```
docker run -it --name akile_monitor_server --restart always -v /CHANGE_PATH/akile_monitor/server/config.json:/app/config.json -v /CHANGE_PATH/akile_monitor/server/ak_monitor.db:/app/ak_monitor.db -p 3000:3000 -e TZ "Asia/Shanghai" niliaerith/akile_monitor_server
```

## Docker Compose 部署

```compose.yml
cat <<EOF > server-compose.yml
services:
  akile_monitor_server:
    image: niliaerith/akile_monitor_server
    container_name: akile_monitor_server
    hostname: akile_monitor_server
    restart: always
    ports:
      - 3000:3000 #主控服务端 端口
    volumes:
      - /CHANGE_PATH/akile_monitor/server/config.json:/app/config.json 
      - /CHANGE_PATH/akile_monitor/server/ak_monitor.db:/app/ak_monitor.db
    environment:
      TZ: "Asia/Shanghai"
EOF
docker compose -f server-compose.yml up -d
```

# 前端 部署

## Docker Cli 部署

```
docker run -it --name akile_monitor_server --restart always -v /CHANGE_PATH/akile_monitor/caddy/config.json:/usr/share/caddy/config.json -p 80:80 -e TZ "Asia/Shanghai" niliaerith/akile_monitor_fe
```

## Docker Compose 部署

```compose.yml
cat <<EOF > fe-compose.yml
services:
  akile_monitor_fe:
    image: niliaerith/akile_monitor_fe
    container_name: akile_monitor_fe
    hostname: akile_monitor_fe
    restart: always
    ports:
      - 80:80 #前端 端口
    volumes:
      - /CHANGE_PATH/akile_monitor/caddy/config.json:/usr/share/caddy/config.json
    environment:
      TZ: "Asia/Shanghai"
EOF
docker compose -f fe-compose.yml up -d
```

# 被控客户端 部署

- 必须添加 `host` 网络模式，否则识别的流量为容器内的
- 必须添加 `/var/run/docker.sock` 卷，否则识别的系统为容器内的

## Docker Cli 部署

```
docker run -it --name akile_monitor_client --restart always -v /CHANGE_PATH/akile_monitor/client/client.json:/app/client.json -v /var/run/docker.sock:/var/run/docker.sock --net host -e TZ "Asia/Shanghai" niliaerith/akile_monitor_client
```

## Docker Compose 部署

```compose.yml
cat <<EOF > client-compose.yml
services:
  akile_monitor_client:
    image: niliaerith/akile_monitor_client
    container_name: akile_monitor_client
    hostname: akile_monitor_client
    restart: always
    network_mode: host
    volumes:
      - /CHANGE_PATH/akile_monitor/client/client.json:/app/client.json
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      TZ: "Asia/Shanghai"
EOF
docker compose -f client-compose.yml up -d
```

# Github Actions 自动构建镜像

- Fork项目
- Settings > Secrets and variables > Actions > New repository secret 添加 `DOCKER_USERNAME` (你的 Docker Hub 用户名) 和 `DOCKER_PASSWORD` (你的 Docker Hub 密码) 两个变量
- Actions 中手动开始工作流 或者 主页Star 或者 修改任意README文档后push触发

# Docker Build 本地构建镜像

```
git clone https://github.com/akile-network/akile_monitor
cd akile_monitor
docker build --target server --tag akile_monitor_server .
docker build --target fe --tag akile_monitor_fe .
docker build --target client --tag akile_monitor_client .
```

# 已知问题

> *因为被控客户端在Docker alpine容器内，所以虚拟化始终显示为`docker`*。
- 解决方法1: 被控客户端采用 二进制部署，详见 [被控端](./README.md)
- 解决方法2: 忽略虚拟化显示内容