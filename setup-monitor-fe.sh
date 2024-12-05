#!/bin/bash

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 权限运行此脚本"
    exit 1
fi

# 检查端口占用函数
check_port() {
    local port=$1
    if command -v lsof >/dev/null 2>&1; then
        local pid=$(lsof -t -i:${port} 2>/dev/null)
        if [ ! -z "$pid" ]; then
            local process=$(lsof -i:${port} | tail -n 1)
            echo "端口 ${port} 已被占用："
            echo "$process"
            return 1
        fi
    else
        local pid=$(netstat -tulpn 2>/dev/null | grep ":${port} " | awk '{print $7}' | cut -d'/' -f1)
        if [ ! -z "$pid" ]; then
            local process=$(netstat -tulpn 2>/dev/null | grep ":${port} ")
            echo "端口 ${port} 已被占用："
            echo "$process"
            return 1
        fi
    fi
    return 0
}

# 检查必需的端口
echo "正在检查端口占用情况..."

# 检查 80 端口
if ! check_port 80; then
    echo "请先释放 80 端口后再运行此脚本"
    exit 1
fi

# 检查 443 端口
if ! check_port 443; then
    echo "请先释放 443 端口后再运行此脚本"
    exit 1
fi

echo "端口检查通过，继续安装..."

# 检测操作系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
fi

# 根据操作系统安装所需包和 Caddy
if command -v apt-get &> /dev/null; then
    # Debian/Ubuntu
    echo "检测到 Debian/Ubuntu 系统"
    apt-get update
    apt-get install -y wget unzip curl debian-keyring debian-archive-keyring apt-transport-https
    
    # 安装 Caddy
    if ! command -v caddy &> /dev/null; then
        echo "正在安装 Caddy..."
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/setup.deb.sh' | bash
        apt-get install caddy
    fi

elif command -v yum &> /dev/null; then
    # CentOS/RHEL
    echo "检测到 CentOS/RHEL 系统"
    yum install -y wget unzip curl yum-utils
    
    # 安装 Caddy
    if ! command -v caddy &> /dev/null; then
        echo "正在安装 Caddy..."
        yum install -y 'dnf-command(copr)'
        yum copr enable -y @caddy/caddy
        yum install -y caddy
    fi
else
    echo "不支持的操作系统"
    exit 1
fi

# 创建目录
echo "创建安装目录..."
mkdir -p /etc/ak_monitor/frontend
cd /etc/ak_monitor/frontend

# 下载并解压前端文件
echo "正在下载前端包..."
wget -O frontend.zip https://github.com/akile-network/akile_monitor_fe/releases/download/v.0.0.2/akile_monitor_fe.zip
echo "正在解压文件..."
unzip -o frontend.zip
rm frontend.zip

# 获取用户域名
read -p "请输入您的域名（例如：monitor.example.com）: " domain

# 创建 Caddy 配置
echo "正在配置 Caddy 服务器..."
cat > /etc/caddy/Caddyfile <<EOF
${domain} {
    root * /etc/ak_monitor/frontend
    file_server
    encode gzip
    try_files {path} /index.html
}
EOF

# 设置适当的权限
if [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
    chown -R caddy:caddy /etc/ak_monitor/frontend
else
    chown -R www-data:www-data /etc/ak_monitor/frontend
fi
chmod -R 755 /etc/ak_monitor/frontend

# 配置防火墙
echo "正在配置防火墙..."
if command -v firewall-cmd &> /dev/null; then
    # CentOS/RHEL 防火墙配置
    firewall-cmd --permanent --zone=public --add-service=http
    firewall-cmd --permanent --zone=public --add-service=https
    firewall-cmd --reload
elif command -v ufw &> /dev/null; then
    # Ubuntu/Debian 防火墙配置
    ufw allow 80/tcp
    ufw allow 443/tcp
fi

# 启动并启用 Caddy 服务
echo "正在启动 Caddy 服务..."
systemctl restart caddy
systemctl enable caddy

echo "安装完成！"
echo "前端已部署到 https://${domain}"
echo "请确保您的 DNS 记录已正确配置，将 ${domain} 指向此服务器的 IP 地址"
echo "Caddy 服务状态："
systemctl status caddy

# 额外信息
if [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
    echo -e "\nCentOS/RHEL 系统的重要提示："
    echo "1. 如果启用了 SELinux，您可能需要运行以下命令："
    echo "   semanage fcontext -a -t httpd_sys_content_t \"/etc/ak_monitor/frontend(/.*)?\" "
    echo "   restorecon -Rv /etc/ak_monitor/frontend"
    echo "2. 如果使用云服务器，请确保在安全组中开放 80 和 443 端口"
fi
