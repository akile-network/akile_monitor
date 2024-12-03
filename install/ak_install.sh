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

get_server_ip(){
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
}

install_akile_monitor(){
    if [ "$shconfig_akile_monitor" = "true" ]; then
        echo -e "${Red}已安装 akile_monitor 主控后端，请勿重复安装${Font}"
        exit 1
    else
        curl -sSL -O https://raw.githubusercontent.com/miaowmint/akile_monitor/refs/heads/main/akile_monitor.sh && chmod +x akile_monitor.sh && bash akile_monitor.sh
        get_server_ip
        source "$config_file"
        echo -e "${Green}主控后端已启动！\n通信密钥auth_secret为：${Red}$shconfig_auth_secret${Green}\n主控端通信url为：${Red}$server_ip:$shconfig_listen${Font}"
    fi
}

install_akile_monitor_fe(){
    if [ "$shconfig_akile_monitor_fe" = "true" ]; then
        echo -e "${Red}已安装 akile_monitor_fe 主控前端，请勿重复安装${Font}"
        exit 1
    else
        curl -sSL -O https://raw.githubusercontent.com/miaowmint/akile_monitor/refs/heads/main/akile_monitor_fe.sh && chmod +x akile_monitor_fe.sh && bash akile_monitor_fe.sh
        source "$config_file"
        echo -e "${Green}主控前端已启动！web页面访问地址为：${Font} $shconfig_weburl ${Green}如需自定义前端页面请前往 ${Red}/etc/ak_monitor/index ${Green}目录${Font}"
    fi
}

install_ak_client(){
    if [ "$shconfig_ak_client" = "true" ]; then
        echo -e "${Red}已安装 ak_client 监控端，请勿重复安装${Font}"
        exit 1
    else
        curl -sSL -O https://raw.githubusercontent.com/miaowmint/akile_monitor/refs/heads/main/ak_client.sh && chmod +x ak_client.sh && bash ak_client.sh
        source "$config_file"
        echo -e "${Green}监控端已启动！\n节点名称为：${Red}$shconfig_name${Green}\n监控的网卡为：${Red}$shconfig_net_name${Font}"
    fi
}

fast_install_ak_client(){
    if [ "$shconfig_akile_monitor" = "true" ]; then
        get_server_ip
        echo -e "${Green}复制以下命令，并在后面添加第四个参数：节点名称 (建议使用 国家缩写-节点名称 例如：HK-Akile)，然后在需要安装ak_client的机器上运行\n${Font}"  
        echo -e "${Red}curl -sSL -O https://raw.githubusercontent.com/miaowmint/akile_monitor/refs/heads/main/ak_client.sh && chmod +x ak_client.sh && bash ak_client.sh $shconfig_auth_secret $server_ip:$shconfig_listen $shconfig_update_uri ${Font}"
    else
        echo -e "${Red}尚未安装 akile_monitor 主控后端，请先安装${Font}"
        exit 1
    fi
}

akile_monitor_config(){
    if [ "$shconfig_akile_monitor" = "true" ]; then
        cat /etc/ak_monitor/config.json
    else
        echo -e "${Red}尚未安装 akile_monitor 主控后端，请先安装${Font}"
        exit 1
    fi
}

akile_monitor_fe_config(){
    if [ "$shconfig_akile_monitor_fe" = "true" ]; then
        if [ "$shconfig_enable_wss" = "true" ]; then
            ws_is="wss://"
        else
            ws_is="ws://"
        fi
        echo "{
            \"socket\": \"$ws_is$shconfig_ws_address$shconfig_web_uri1\",
            \"apiURL\": \"$shconfig_weburl\"
        }"
    else
        echo -e "${Red}尚未安装 akile_monitor_fe 主控前端，请先安装${Font}"
        exit 1
    fi
    
}

ak_client_config(){
    if [ "$shconfig_ak_client" = "true" ]; then
        cat /etc/ak_monitor/client.json
    else
        echo -e "${Red}尚未安装 ak_client 监控端，请先安装${Font}"
        exit 1
    fi
    
}

uninstall_akile_monitor(){
    systemctl stop ak_monitor
    systemctl disable ak_monitor
    rm /etc/systemd/system/ak_monitor.service
    systemctl daemon-reload
    rm -f /etc/ak_monitor/ak_monitor
    rm -f /etc/ak_monitor/config.json
    echo -e "${Green}卸载完毕${Font}"
    sed -i "s|^shconfig_akile_monitor=\"[^\"]*\"|shconfig_akile_monitor=\"false\"|" $config_file
}

uninstall_akile_monitor_fe(){
    docker stop akile_monitor_fe && docker rm akile_monitor_fe && docker rmi akile_monitor_fe
    rm -rf /etc/ak_monitor/index
    echo -e "${Green}卸载完毕${Font}"
    sed -i "s|^shconfig_akile_monitor_fe=\"[^\"]*\"|shconfig_akile_monitor_fe=\"false\"|" $config_file
}

uninstall_ak_client(){
    systemctl stop ak_client
    systemctl disable ak_client
    rm /etc/systemd/system/ak_client.service
    systemctl daemon-reload
    rm -f /etc/ak_monitor/client
    rm -f /etc/ak_monitor/client.json
    echo -e "${Green}卸载完毕${Font}"
    sed -i "s|^shconfig_ak_client=\"[^\"]*\"|shconfig_ak_client=\"false\"|" $config_file
}

clear
source_config_file
echo '           _                               _       _   '
echo ' _ __ ___ (_) __ _  _____      ___ __ ___ (_)_ __ | |_ '
echo '| '"'"'_ ` _ \| |/ _` |/ _ \ \ /\ / / '"'"'_ ` _ \| | '"'"'_ \| __|'
echo '| | | | | | | (_| | (_) \ V  V /| | | | | | | | | | |_ '
echo '|_| |_| |_|_|\__,_|\___/ \_/\_/ |_| |_| |_|_|_| |_|\__|'
echo '                                                       '

if [ -n "$1" ]; then
    choice="$1"
else
    echo -e "———————————————————————————————————————"
    echo -e "${Green}0、退出脚本${Font}"
    echo -e "${Green}1、安装akile_monitor主控后端${Font}"
    echo -e "${Green}2、安装akile_monitor_fe主控前端${Font}"
    echo -e "${Green}3、安装ak_client监控端${Font}"
    echo -e "${Green}4、查看ak_client快速安装命令${Font}"
    echo -e "${Green}5、查看已安装的akile_monitor主控后端配置${Font}"
    echo -e "${Green}6、查看已安装的akile_monitor_fe主控前端配置${Font}"
    echo -e "${Green}7、查看已安装的ak_client监控端配置${Font}"
    echo -e "${Green}8、卸载akile_monitor主控后端${Font}"
    echo -e "${Green}9、卸载akile_monitor_fe主控前端${Font}"
    echo -e "${Green}10、卸载ak_client监控端${Font}"
    echo -e "———————————————————————————————————————"
    read -p "请输入数字 [0-10]: " choice
fi

if [ "$choice" == "0" ]; then
    echo "退出脚本"
    exit 0
elif [ "$choice" == "1" ]; then
    install_akile_monitor
elif [ "$choice" == "2" ]; then
    install_akile_monitor_fe
elif [ "$choice" == "3" ]; then
    install_ak_client
elif [ "$choice" == "4" ]; then
    fast_install_ak_client
elif [ "$choice" == "5" ]; then
    akile_monitor_config
elif [ "$choice" == "6" ]; then
    akile_monitor_fe_config
elif [ "$choice" == "7" ]; then
    ak_client_config
elif [ "$choice" == "8" ]; then
    uninstall_akile_monitor
elif [ "$choice" == "9" ]; then
    uninstall_akile_monitor_fe
elif [ "$choice" == "10" ]; then
    uninstall_ak_client
else
    clear
    echo -e "${Green}请输入正确的数字 [0-10]${Font}"
    sleep 1s
    curl -sSL -O https://raw.githubusercontent.com/miaowmint/akile_monitor/refs/heads/main/ak_install.sh && chmod +x ak_install.sh && bash ak_install.sh
fi
