#!/bin/bash

set -e

echo "📥 下载 Android Studio..."
cd /tmp
rm -f android-studio.tar.gz
wget https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2024.3.2.15/android-studio-2024.3.2.15-linux.tar.gz -O android-studio.tar.gz

echo "📦 解压并安装 Android Studio..."
tar -xzf android-studio.tar.gz
sudo mv android-studio /opt/
sudo ln -sf /opt/android-studio/bin/studio.sh /usr/local/bin/android-studio

echo "✅ 安装完成！"
echo "👉 可通过命令 'android-studio' 启动 Android Studio"

echo "🎯 创建 Android Studio 桌面快捷方式..."

DESKTOP_FILE="$HOME/.local/share/applications/android-studio.desktop"

mkdir -p "$(dirname "$DESKTOP_FILE")"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Icon=/opt/android-studio/bin/studio.png
Exec="/opt/android-studio/bin/studio.sh" %f
Comment=The official IDE for Android development
Categories=Development;IDE;
Terminal=false
StartupNotify=true
EOF

chmod +x "$DESKTOP_FILE"

mkdir -p ~/Desktop
cp $DESKTOP_FILE ~/Desktop/android-studio.desktop

echo "✅ 快捷方式创建成功！你可以在桌面或者应用菜单中搜索 'Android Studio' 打开它。"
