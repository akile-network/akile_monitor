#!/bin/bash
# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
 echo "Please run as root"
 exit 1
fi

# Install bc based on system package manager
if command -v apk > /dev/null; then
    apk update && apk add bc
else
    echo "It's not alpine."
    exit 1
fi

# Stop existing service if running
rc-service ak_client stop

# Function to detect main network interface
get_main_interface() {
   local interfaces=$(ip -o link show | \
       awk -F': ' '$2 !~ /^((lo|docker|veth|br-|virbr|tun|vnet|wg|vmbr|dummy|gre|sit|vlan|lxc|lxd|warp|tap))/{print $2}' | \
       grep -v '@')
   
   local interface_count=$(echo "$interfaces" | wc -l)
   
   # 格式化流量大小的函数
   format_bytes() {
       local bytes=$1
       if [ $bytes -lt 1024 ]; then
           echo "${bytes} B"
       elif [ $bytes -lt 1048576 ]; then # 1024*1024
           echo "$(echo "scale=2; $bytes/1024" | bc) KB"
       elif [ $bytes -lt 1073741824 ]; then # 1024*1024*1024
           echo "$(echo "scale=2; $bytes/1024/1024" | bc) MB"
       elif [ $bytes -lt 1099511627776 ]; then # 1024*1024*1024*1024
           echo "$(echo "scale=2; $bytes/1024/1024/1024" | bc) GB"
       else
           echo "$(echo "scale=2; $bytes/1024/1024/1024/1024" | bc) TB"
       fi
   }
   
   # 显示网卡流量的函数
   show_interface_traffic() {
       local interface=$1
       if [ -d "/sys/class/net/$interface" ]; then
           local rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes)
           local tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes)
           echo "   ↓ Received: $(format_bytes $rx_bytes)"
           echo "   ↑ Sent: $(format_bytes $tx_bytes)"
       else
           echo "   无法读取流量信息"
       fi
   }
   
   # 如果没有找到合适的接口或有多个接口时显示所有可用接口
   echo "所有可用的网卡接口:" >&2
   echo "------------------------" >&2
   local i=1
   while read -r interface; do
       echo "$i) $interface" >&2
       show_interface_traffic "$interface" >&2
       i=$((i+1))
   done < <(ip -o link show | grep -v "lo:" | awk -F': ' '{print $2}')
   echo "------------------------" >&2
   
   while true; do
       read -p "请选择网卡，如上方显示异常或没有需要的网卡，请直接填入网卡名: " selection
       
       # 检查是否为数字
       if [[ "$selection" =~ ^[0-9]+$ ]]; then
           # 如果是数字，检查是否在有效范围内
           selected_interface=$(ip -o link show | grep -v "lo:" | sed -n "${selection}p" | awk -F': ' '{print $2}')
           if [ -n "$selected_interface" ]; then
               echo "已选择网卡: $selected_interface" >&2
               echo "$selected_interface"
               break
           else
               echo "无效的选择，请重新输入" >&2
               continue
           fi
       else
           # 直接使用输入的网卡名
           echo "已选择网卡: $selection" >&2
           echo "$selection"
           break
       fi
   done
}

# Check if all arguments are provided
if [ "$#" -ne 3 ]; then
 echo "Usage: $0 <auth_secret> <url> <name>"
 echo "Example: $0 your_secret wss://api.123.321 HK-Akile"
 exit 1
fi

# Get system architecture
ARCH=$(uname -m)
CLIENT_FILE="akile_client-linux-amd64"

# Set appropriate client file based on architecture
if [ "$ARCH" = "x86_64" ]; then
 CLIENT_FILE="akile_client-linux-amd64"
elif [ "$ARCH" = "aarch64" ]; then
 CLIENT_FILE="akile_client-linux-arm64"
elif [ "$ARCH" = "x86_64" ] && [ "$(uname -s)" = "Darwin" ]; then
 CLIENT_FILE="akile_client-darwin-amd64"
else
 echo "Unsupported architecture: $ARCH"
 exit 1
fi

# Assign command line arguments to variables
auth_secret="$1"
url="$2"
monitor_name="$3"

# Get network interface
net_name=$(get_main_interface)
echo "Using network interface: $net_name"

# Create directory and change to it
mkdir -p /etc/ak_monitor/
cd /etc/ak_monitor/

# Download client
wget -O client https://github.com/akile-network/akile_monitor/releases/latest/download/$CLIENT_FILE
chmod 777 client

# Create openrc service file
cat > /etc/init.d/ak_client << 'EOF'
#!/sbin/openrc-run

# 定义服务的名称变量
name="AkileCloud Monitor Service"

# 定义服务的执行路径，将使用该路径启动服务程序
command="/etc/ak_monitor/client"

# 定义服务的启动参数
# command_args="--param1 value1 --param2 value2"

# 提供服务的描述信息
description="Custom service for ${name}"

# 定义服务的依赖关系
depend() {
    # 指定该服务需要网络（net 服务）支持
    need net
}

# 在启动服务之前的预处理函数
start_pre() {
    # 打印启动前的消息
    ebegin "Preparing to start ${name}"
    # 可以在这里添加任何启动服务之前的准备工作
    eend $? # eend 会输出函数操作的结果状态，$? 表示上一个命令的返回值
}

# 启动服务的函数
start() {
    # 打印启动消息
    ebegin "Starting ${name}"
    # 切换到工作目录
    cd /etc/ak_monitor/
    # 使用 start-stop-daemon 命令启动服务
    start-stop-daemon --start --exec ${command}
    eend $? # 输出启动操作的结果状态
}

# 停止服务的函数
stop() {
    # 打印停止消息
    ebegin "Stopping ${name}"
    # 使用 start-stop-daemon 命令停止服务
    start-stop-daemon --stop --exec ${command}
    eend $? # 输出停止操作的结果状态
}

# 重新启动服务的函数
restart() {
    # 打印重新启动消息
    ebegin "Restarting ${name}"
    # 停止服务
    start-stop-daemon --stop --exec ${command}
    # 等待 1 秒钟，确保服务完全停止
    sleep 1
    # 启动服务
    start-stop-daemon --start --exec ${command}
    eend $? # 输出重新启动操作的结果状态
}
EOF

# Create client configuration
cat > /etc/ak_monitor/client.json << EOF
{
"auth_secret": "${auth_secret}",
"url": "${url}",
"net_name": "${net_name}",
"name": "${monitor_name}"
}
EOF

# Set proper permissions
chmod 644 /etc/ak_monitor/client.json
chmod 755 /etc/init.d/ak_client

# Add service to default runlevel
rc-update add ak_client default

# Start service
rc-service ak_client start

echo "Installation complete! Service status:"
rc-service ak_client status
