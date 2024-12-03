#!/bin/bash

#  _ __ ___ (_) __ _  _____      ___ __ ___ (_)_ __ | |_ 
# | '_ ` _ \| |/ _` |/ _ \ \ /\ / / '_ ` _ \| | '_ \| __|
# | | | | | | | (_| | (_) \ V  V /| | | | | | | | | | |_ 
# |_| |_| |_|_|\__,_|\___/ \_/\_/ |_| |_| |_|_|_| |_|\__|

# 主控后端
shconfig_auth_secret="" # 通信密钥
shconfig_listen="" # ws监听端口
shconfig_enable_tg="" # 是否启用TG通知
shconfig_tg_token="" # TGbotToken
shconfig_update_uri="" # 监控端与主控端通信用的uri
shconfig_web_uri="" # 查看网页面板的时候与主控端通信用的uri
shconfig_hook_uri="" # AkileMonitorBot与主控端通信用的uri
shconfig_hook_token="" # hook通信使用的token
shconfig_akile_monitor="false"
# 主控前端
shconfig_web_port="" # web面板监听端口
shconfig_enable_wss="" # web面板是否会使用HTTPS
shconfig_weburl="" # web面板url
shconfig_ws_address="" # 主控端通信url
shconfig_web_uri1="" # 查看网页面板的时候与主控端通信用的uri
shconfig_akile_monitor_fe="false"
# 监控端
shconfig_auth_secret1="" # 通信密钥
shconfig_url="" # 主控端通信url
shconfig_uri="" # 监控端与主控端通信用的uri
shconfig_name="" # 节点名称
shconfig_net_name="" # 网卡名
shconfig_ak_client="false"
