#!/bin/bash

set -e

echo "🔄 更新系统..."
sudo apt update && sudo apt upgrade -y

echo "📦 安装 Xfce 桌面环境..."
sudo apt install -y xfce4 xfce4-goodies

echo "🖥️ 安装 xrdp 远程桌面服务..."
sudo apt install -y xrdp
sudo systemctl enable xrdp
sudo systemctl start xrdp

echo "🛠️ 配置 xrdp 使用 Xfce..."
# xrdp 登录时使用 startxfce4 启动 XFCE 桌面环境
echo "startxfce4" > ~/.xsession
# /etc/skel/ 是系统在创建新用户时默认复制配置文件的地方
sudo cp ~/.xsession /etc/skel/.xsession

echo "🔓 开放 RDP 端口..."
sudo ufw allow 3389/tcp || echo "⚠️ 防火墙未启用或 ufw 未安装"

echo "⬇️ 安装firefox浏览器"
sudo apt install -y firefox

echo "✅ 所有步骤完成。你现在可以使用 Windows 远程桌面 (mstsc) 连接此主机（端口 3389）。如果连接不上请联系运维开通端口"
