#!/bin/bash

#  _ __ ___ (_) __ _  _____      ___ __ ___ (_)_ __ | |_ 
# | '_ ` _ \| |/ _` |/ _ \ \ /\ / / '_ ` _ \| | '_ \| __|
# | | | | | | | (_| | (_) \ V  V /| | | | | | | | | | |_ 
# |_| |_| |_|_|\__,_|\___/ \_/\_/ |_| |_| |_|_|_| |_|\__|

Green="\033[32m"
Font="\033[0m"
Red="\033[31m"

check_source_config_file(){
    mkdir -p /etc/ak_monitor/ && cd /etc/ak_monitor/

    config_file="/etc/ak_monitor/shconfig.sh"

    if [ ! -f "$config_file" ]; then
        echo "$config_file 不存在，正在下载..."
        download_url="https://raw.githubusercontent.com/miaowmint/akile_monitor/refs/heads/main/shconfig.sh"
        wget -O "$config_file" "$download_url"
    fi
}

select_download_file(){
    os=$(uname -s)
    arch=$(uname -m)
    
    if [[ "$os" == "Linux" ]]; then
        if [[ "$arch" == "x86_64" ]]; then
            file="akile_client-linux-amd64"
        elif [[ "$arch" == "aarch64" ]]; then
            file="akile_client-linux-arm64"
        else
            echo -e "${Red}似乎是不支持的架构: $arch on $os ${Font}"
            exit 1
        fi
    elif [[ "$os" == "Darwin" ]]; then
        if [[ "$arch" == "x86_64" ]]; then
            file="akile_client-darwin-amd64"
        elif [[ "$arch" == "aarch64" ]]; then
            file="akile_client-darwin-arm64"
        else
            echo -e "${Red}似乎是不支持的架构: $arch on $os ${Font}"
            exit 1
        fi
    else
        echo -e "${Red}似乎是不支持的系统？: $os${Font}"
        exit 1
    fi
}

configure_akile_monitor_client(){
    default_auth_secret="default_auth_secret"
    default_url="12.13.14.15:3000"
    default_uri="/monitor"
    default_name="HK-Akile"
    default_net_name=$(ip link show | awk '/^[0-9]+: / {print $2}' | sed 's/:$//' | grep -v 'lo' | head -n 1)

    echo -e "${Green}请输入通信密钥 auth_secret ，与主控端设置的通信密钥相同: ${Font}"
    read auth_secret
    if [ -z "$auth_secret" ]; then
        auth_secret=$default_auth_secret
    fi
    sed -i "s|^shconfig_auth_secret1=\"[^\"]*\"|shconfig_auth_secret1=\"$auth_secret\"|" $config_file

    echo -e "${Green}请输入主控端通信url (不要带http://，例如：12.13.14.15:3000) : ${Font}"
    read url
    if [ -z "$url" ]; then
        url=$default_url
    fi
    sed -i "s|^shconfig_url=\"[^\"]*\"|shconfig_url=\"$url\"|" $config_file

    echo -e "${Green}请输入主控端通信uri (例如：/monitor，注意带 / ，默认为/monitor) : ${Font}"
    read uri
    if [ -z "$uri" ]; then
        uri=$default_uri
    fi
    sed -i "s|^shconfig_uri=\"[^\"]*\"|shconfig_uri=\"$uri\"|" $config_file

    echo -e "${Green}请输入节点名称 (建议使用 国家缩写-节点名称 例如：HK-Akile) : ${Font}"
    read name
    if [ -z "$name" ]; then
        name=$default_name
    fi
    sed -i "s|^shconfig_name=\"[^\"]*\"|shconfig_name=\"$name\"|" $config_file

    echo -e "${Green}请输入监控的网卡名 net_name (例如：eth0，已自动获取到的默认值：$default_net_name) ${Red}如果不懂请不要修改此项，直接回车！！！: ${Font}"
    read net_name
    if [ -z "$net_name" ]; then
        net_name=$default_net_name
    fi
    sed -i "s|^shconfig_net_name=\"[^\"]*\"|shconfig_net_name=\"$auth_secret\"|" $config_file

    install_akile_monitor_client
}
# 安装akile_monitor
install_akile_monitor_client(){
    select_download_file
    
    # 下载ak_client
    mkdir -p /etc/ak_monitor/ && cd /etc/ak_monitor/
    echo -e "${Green}开始下载 $file${Font}"
    wget -O client https://github.com/akile-network/akile_monitor/releases/download/v0.01/$file && chmod 777 client

    # client.json
    cat > /etc/ak_monitor/client.json << EOF

{
  "auth_secret": "${auth_secret}",
  "url": "ws://${url}${uri}",
  "net_name": "${net_name}",
  "name": "${name}"
}

EOF

    cat /etc/ak_monitor/client.json

    # ak_client.service
    cat > /etc/systemd/system/ak_client.service <<EOF
[Unit]
Description=AkileCloud Monitor Service
After=network.target nss-lookup.target
Wants=network.target

[Service]
User=root
Group=root
Type=simple
LimitAS=infinity
LimitRSS=infinity
LimitCORE=infinity
LimitNOFILE=999999999
WorkingDirectory=/etc/ak_monitor/
ExecStart=/etc/ak_monitor/client
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target

EOF

    # 启用服务，使其开机自启动
    systemctl daemon-reload
    systemctl start ak_client
    systemctl enable ak_client
}

check_source_config_file

if [ $# -eq 4 ]; then
    auth_secret=$1
    url=$2
    uri=$3
    name=$4
    net_name=$(ip link show | awk '/^[0-9]+: / {print $2}' | sed 's/:$//' | grep -v 'lo' | head -n 1)

    sed -i "s|^shconfig_auth_secret1=\"[^\"]*\"|shconfig_auth_secret1=\"$auth_secret\"|" $config_file
    sed -i "s|^shconfig_url=\"[^\"]*\"|shconfig_url=\"$url\"|" $config_file
    sed -i "s|^shconfig_uri=\"[^\"]*\"|shconfig_uri=\"$uri\"|" $config_file
    sed -i "s|^shconfig_name=\"[^\"]*\"|shconfig_name=\"$name\"|" $config_file
    sed -i "s|^shconfig_net_name=\"[^\"]*\"|shconfig_net_name=\"$auth_secret\"|" $config_file

    install_akile_monitor_client

elif [ $# -lt 4 ]; then
    echo -e "${Red}错误: 脚本需要传递四个参数或不传参数${Font}"
    echo -e "${Red}第四个参数应为节点名称 (建议使用 国家缩写-节点名称 例如：HK-Akile) ${Font}"
    exit 1
else
    configure_akile_monitor_client
fi

sed -i "s|^shconfig_ak_client=\"[^\"]*\"|shconfig_ak_client=\"true\"|" $config_file
