#!/bin/bash

set -e

# 获取当前登录会话的原始用户名
REAL_USER=$(logname)
# 安全解析该用户的 home 目录
USER_HOME=$(eval echo "~$REAL_USER")

# 获取最新版本的android_studio下载链接
get_latest_android_studio_url() {
  local url
  url=$(curl -s https://developer.android.com/studio | grep -Eo 'https://redirector.gvt1.com/edgedl/android/studio/ide-zips/[^"]+/android-studio-[^"]+-linux.tar.gz' | head -n 1)

  if [[ -z "$url" ]]; then
    echo "❌ 无法从官网获取最新下载链接。" >&2
    return 1
  fi

  echo "$url"
}

echo "📥 下载 Android Studio..."
# 在临时目录下载文件
cd /tmp

# 删除之前下载的文件
sudo rm -f android-studio.tar.gz
wget "$(get_latest_android_studio_url)" -O android-studio.tar.gz

echo "📦 解压并安装 Android Studio..."
sudo rm -rf android-studio
tar -xzf android-studio.tar.gz
# 卸载之前的版本
sudo rm -rf /opt/android-studio
sudo mv android-studio /opt/
sudo ln -sf /opt/android-studio/bin/studio.sh /usr/local/bin/android-studio

echo "✅ 安装完成！"
echo "👉 可通过命令 'android-studio' 启动 Android Studio"

echo "🎯 创建 Android Studio 桌面快捷方式..."

# 在用户目录下创建快捷方式
sudo -u $REAL_USER $SHELL <<'SH_EOF'
DESKTOP_FILE="$HOME/.local/share/applications/android-studio.desktop"

mkdir -p "$(dirname "$DESKTOP_FILE")"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Icon=/opt/android-studio/bin/studio.png
Exec=bash -lc "/opt/android-studio/bin/studio.sh" %f
Comment=The official IDE for Android development
Categories=Development;IDE;
Terminal=false
StartupNotify=true
EOF

chmod +x "$DESKTOP_FILE"

mkdir -p ~/Desktop
cp $DESKTOP_FILE ~/Desktop/android-studio.desktop
SH_EOF

echo "✅ 快捷方式创建成功！你可以在桌面或者应用菜单中搜索 'Android Studio' 打开它。"
