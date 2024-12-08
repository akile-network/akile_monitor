# Akile Monitor

![预览图](https://github.com/akile-network/akile_monitor/blob/main/akile-monitor-cover.jpg?raw=true)
Demo https://cpu.icu


前端项目地址 https://github.com/akile-network/akile_monitor_fe

## [Docker部署](./DOCKER.md)

## 前后端集合一键脚本

```
wget -O ak-setup.sh "https://raw.githubusercontent.com/akile-network/akile_monitor/refs/heads/main/ak-setup.sh" && chmod +x ak-setup.sh && sudo ./ak-setup.sh
```
![image](https://github.com/user-attachments/assets/58b9209b-a327-4783-b9dd-4e0dc2ecbf7e)

## 主控后端

```
wget -O setup-monitor.sh "https://raw.githubusercontent.com/akile-network/akile_monitor/refs/heads/main/setup-monitor.sh" && chmod +x setup-monitor.sh && sudo ./setup-monitor.sh
```

## 被控端

```
wget -O setup-client.sh "https://raw.githubusercontent.com/akile-network/akile_monitor/refs/heads/main/setup-client.sh" && chmod +x setup-client.sh && sudo ./setup-client.sh <your_secret> <url> <name>
```
如
```
wget -O setup-client.sh "https://raw.githubusercontent.com/akile-network/akile_monitor/refs/heads/main/setup-client.sh" && chmod +x setup-client.sh && sudo ./setup-client.sh 123321 wss://123.321.123.321/monitor HKLite-One-Akile
```

## 主控前端部署教程(cf pages)

### 1.下载

https://github.com/akile-network/akile_monitor_fe/releases/download/v.0.0.2/akile_monitor_fe.zip


### 2.修改config.json为自己的api地址（公网地址）（如果前端要加ssl 后端也要加ssl 且此处记得改为https和wss）

```
{
  "socket": "ws(s)://192.168.31.64:3000/ws",
  "apiURL": "http(s)://192.168.31.64:3000"
}
```

### 3.直接上传文件夹至cf pages

![image](https://github.com/user-attachments/assets/c9e5a950-045a-4a7f-8b30-00899994c8cf)
![image](https://github.com/user-attachments/assets/c4096133-694d-4c2a-8d90-f92e48de6e9b)

### 4.设置域名（可选）

![image](https://github.com/user-attachments/assets/14adc0cf-2292-4148-a913-7a466e441d71)
