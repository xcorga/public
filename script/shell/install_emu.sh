#!/bin/bash
set -e

# 安装docker
if dpkg -l | grep -q "docker"; then
    echo "Docker 已安装"
else
    curl -fsSL https://get.docker.com | sudo bash
fi

# 安装内核模块扩展包
apt install linux-modules-extra-`uname -r`
# 加载binder_linux模块
modprobe binder_linux devices="binder,hwbinder,vndbinder"

# 开机自动加载 binder_linux 模块
echo "binder_linux" | sudo tee /etc/modules-load.d/binder_linux.conf
sudo tee /etc/modprobe.d/binder_linux.conf <<EOF
options binder_linux devices="binder,hwbinder,vndbinder"
EOF

# 安装redroid
containerName="redroid"
if ! docker ps -a --format '{{.Names}}' | grep -q "$containerName"; then
  docker run -itd --privileged \
    -p 5555:5555 \
    --name "$containerName" \
    --restart=unless-stopped \
    redroid/redroid:15.0.0-latest
else
  echo "$containerName 已安装"
  docker start "$containerName"
fi

# 安装ws-scrcpy
if ! docker ps -a --format '{{.Names}}' | grep -q "ws-scrcpy"; then
  # 手动打包ws-scrcpy镜像，docker仓库里面的太老了
  docker build -t ws-scrcpy -f - "$(mktemp -d)" <<EOF
FROM node:18
MAINTAINER Scavin <scavin@appinn.com>

ENV LANG C.UTF-8
WORKDIR /ws-scrcpy

RUN npm install -g node-gyp
RUN apt update;apt install android-tools-adb -y
RUN git clone https://github.com/NetrisTV/ws-scrcpy.git .
RUN npm install
RUN npm run dist

EXPOSE 8000

CMD ["node","dist/index.js"]
EOF
  # 启动ws-scrcpy容器
  docker run --name ws-scrcpy --restart=unless-stopped -d -p 8000:8000 ws-scrcpy
else
  echo "ws-scrcpy 已安装"
  docker start ws-scrcpy
fi

# 写入脚本，监听端口可用时ws-scrcpy自动连接adb
cat << 'EOF' > /usr/local/bin/adb_connect_docker.sh
#!/bin/bash

CONTAINER_NAME="redroid"
CONTAINER_IP="$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME")"
ADB_PORT="5555"
MAX_RETRIES=3600

echo "$(date) - 等待容器 $CONTAINER_NAME 启动..."

# 等待容器运行
while true; do
  if docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q true; then
    echo "$(date) - 容器已启动"
    break
  fi
  echo "$(date) - 容器未启动，继续等待..."
  sleep 2
done

# 重试 adb connect
ADB_TARGET="$CONTAINER_IP:$ADB_PORT"
for i in $(seq 1 $MAX_RETRIES); do
  echo "$(date) - 第 $i 次尝试连接 adb: $ADB_TARGET"
  docker exec ws-scrcpy adb connect "$ADB_TARGET"

  # 判断是否连接成功（可按需启用更严格检测）
  if docker exec ws-scrcpy adb devices | grep -q "$ADB_TARGET"; then
    echo "$(date) - 成功连接到 adb: $ADB_TARGET"
    docker exec ws-scrcpy adb -s "$ADB_TARGET" root
    exit 0
  fi

  echo "$(date) - 连接失败，等待重试..."
  sleep 3
done

echo "$(date) - 超过最大重试次数，连接失败"
exit 1
EOF

sudo chmod +x /usr/local/bin/adb_connect_docker.sh

# 创建 systemd 服务文件
cat << 'EOF' > /etc/systemd/system/adb_connect_docker.service
[Unit]
Description=等待Docker容器启动并让ws-scrcpy自动连接adb设备
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/local/bin/adb_connect_docker.sh
Restart=on-failure
Environment=PATH=/usr/bin:/usr/local/bin

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable adb_connect_docker.service
sudo systemctl start adb_connect_docker.service

echo "redroid安卓模拟器部署完成"
serverIp=$(curl -s ifconfig.me)
echo "浏览器打开'$serverIp:8000'查看设备列表"
# echo "使用scrcpy -s '$serverIp:5555'连接远程模拟器"
echo "打不开请联系运维打开端口"

