#!/bin/bash

#  _ __ ___ (_) __ _  _____      ___ __ ___ (_)_ __ | |_ 
# | '_ ` _ \| |/ _` |/ _ \ \ /\ / / '_ ` _ \| | '_ \| __|
# | | | | | | | (_| | (_) \ V  V /| | | | | | | | | | |_ 
# |_| |_| |_|_|\__,_|\___/ \_/\_/ |_| |_| |_|_|_| |_|\__|

Green="\033[32m"
Font="\033[0m"
Red="\033[31m"

source_config_file(){
    mkdir -p /etc/ak_monitor/ && cd /etc/ak_monitor/

    config_file="/etc/ak_monitor/shconfig.sh"

    if [ ! -f "$config_file" ]; then
        echo "$config_file 不存在，正在下载..."
        download_url="https://raw.githubusercontent.com/miaowmint/akile_monitor/refs/heads/main/shconfig.sh"
        wget -O "$config_file" "$download_url"
    fi
    
    source "$config_file"
}

install_docker(){
    if [[ $(curl -s "https://www.loliapi.com/getip/?type=country") == "CN" ]]; then
        echo -e "${Green}检测到服务器位于中国大陆，开始测速并使用docker境内安装源${Font}"
        sources=(
            "https://mirrors.aliyun.com/docker-ce"
            "https://mirrors.tencent.com/docker-ce"
            "https://mirrors.163.com/docker-ce"
            "https://mirrors.cernet.edu.cn/docker-ce"
        )
        get_average_delay() {
            local source=$1
            local total_delay=0
            local iterations=3
            for ((i = 0; i < iterations; i++)); do
                delay=$(curl -o /dev/null -s -w "%{time_total}\n" "$source")
                total_delay=$(awk "BEGIN {print $total_delay + $delay}")
            done
            average_delay=$(awk "BEGIN {print $total_delay / $iterations}")
            echo "$average_delay"
        }
        min_delay=${#sources[@]}
        selected_source=""
        for source in "${sources[@]}"; do
            average_delay=$(get_average_delay "$source")
            if (( $(awk 'BEGIN { print '"$average_delay"' < '"$min_delay"' }') )); then
                min_delay=$average_delay
                selected_source=$source
            fi
        done
        if [ -n "$selected_source" ]; then
            echo -e "${Green}选择延迟最低的源 $selected_source ，延迟为 $min_delay 秒${Font}"
            export DOWNLOAD_URL="$selected_source"
        else
            echo -e "${Red}无法选择境内安装源，使用默认官方源${Font}"
        fi
    else
        echo -e "${Red}服务器位于非中国大陆地区，继续${Font}"   
    fi
    sleep 1s
    curl -fsSL https://get.docker.minq.cn | bash -s docker
    configure_docker
}

configure_docker(){
    rm -f /etc/docker/daemon.json
    if [[ $(curl -s "https://www.loliapi.com/getip/?type=country") == "CN" ]]; then
    echo "服务器位于中国，添加加速镜像源"
    curl -sSLk https://www.minq.cn/dockerdaemoncn.json -o /etc/docker/daemon.json
    else
    echo "服务器不位于中国，使用默认配置文件"
    curl -sSLk https://www.minq.cn/dockerdaemon.json -o /etc/docker/daemon.json
    fi
    systemctl daemon-reload
    systemctl restart docker
    echo -e "${Green}docker配置完成${Font}"
    sleep 1s
    cat /etc/docker/daemon.json
}

main(){

    server_ip=$(wget -qO- https://4.ipw.cn/)
    if [ -z "$server_ip" ]; then
    echo -e "${Red}无法联网获取服务器IP，尝试通过网卡配置获取服务器IP${Font}"
    net_name=$(ip link show | awk '/^[0-9]+: / {print $2}' | sed 's/:$//' | grep -v 'lo' | head -n 1)
    server_ip=$(ip addr show $net_name | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        if [ -z "$server_ip" ]; then
        echo -e "${Red}无法获取服务器IP，继续执行脚本...${Font}"
        server_ip="你的服务器IP"
        fi
    fi

    echo -e "${Green}请输入web面板监听端口（默认: 8080）：${Font}"
    read web_port
    web_port=${web_port:-"8080"}
    sed -i "s|^shconfig_web_port=\"[^\"]*\"|shconfig_web_port=\"$web_port\"|" $config_file

    echo -e "${Green}你的web面板是否会使用HTTPS访问? (若直接IP:端口访问面板或仍使用http，直接回车默认 false 即可) 输入 true 启用 WSS: ${Font}"
    read enable_wss
    enable_wss=${enable_wss:-"false"}
    sed -i "s|^shconfig_enable_wss=\"[^\"]*\"|shconfig_enable_wss=\"$enable_wss\"|" $config_file

    echo -e "${Green}请输入你的web面板url(如 http://12.13.14.15:8080 ，要带http://，回车默认使用 ${Font}服务器IP:web面板监听端口 ${Green}http://$server_ip:$web_port): ${Font}"
    read weburl
    weburl=${weburl:-"http://$server_ip:$web_port"}
    sed -i "s|^shconfig_weburl=\"[^\"]*\"|shconfig_weburl=\"$weburl\"|" $config_file
    
    listen="${shconfig_listen:-3000}"
    echo -e "${Green}请输入主控端通信url(如 12.13.14.15:3000 ，不要带http://，回车默认使用 ${Font}服务器IP:安装主控后端时配置的ws监听端口 ${Green}$server_ip:$listen): ${Font}"
    read ws_address
    ws_address=${ws_address:-"$server_ip:$listen"}
    sed -i "s|^shconfig_ws_address=\"[^\"]*\"|shconfig_ws_address=\"$ws_address\"|" $config_file

    echo -e "${Green}请输入安装主控后端时配置的 web_uri （默认 /ws）：${Font}"
    read web_uri
    web_uri=${web_uri:-"/ws"}
    sed -i "s|^shconfig_web_uri1=\"[^\"]*\"|shconfig_web_uri1=\"$web_uri\"|" $config_file


    if command -v docker &> /dev/null; then
        echo "Docker 已安装，继续执行脚本..."
    else
        echo "Docker 未安装，安装 Docker"
        install_docker
    fi

    #构建docker镜像
    mkdir -p /etc/ak_monitor/ && cd /etc/ak_monitor/
    wget -O Dockerfile https://raw.githubusercontent.com/miaowmint/akile_monitor/refs/heads/main/Dockerfile
    docker build -t akile_monitor_fe .

    # Docker，启动！
    docker_cmd="docker run -d \
        --name akile_monitor_fe \
        --restart unless-stopped \
        -p $web_port:80 \
        -e API_URL=\"$weburl\" \
        -e ENABLE_WSS=$enable_wss \
        -e SOCKET=\"$ws_address\" \
        -e WEB_URI=$web_uri \
        -v /etc/ak_monitor/index:/usr/share/nginx/html \
        akile_monitor_fe"

    echo -e "${Green}正在启动 Docker 容器...${Font}"
    echo -e "${Green}执行命令: $docker_cmd${Font}"

    # 执行 Docker 启动命令
    eval $docker_cmd
}

source_config_file

main

sed -i "s|^shconfig_akile_monitor_fe=\"[^\"]*\"|shconfig_akile_monitor_fe=\"true\"|" $config_file
