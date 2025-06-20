#!/bin/bash
set -e

echo "📦 Step 1: 安装必要依赖..."
sudo apt update
sudo apt install -y openjdk-21-jdk wget unzip curl lib32z1 libstdc++6 libncurses5

echo "✅ 依赖安装完成。"

# 配置路径
SDK_ROOT="$HOME/Android/Sdk"
TOOLS_DIR="$SDK_ROOT/cmdline-tools"
TOOL_VERSION="latest"
SDK_ZIP_URL="https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip"

echo "📁 Step 2: 准备 SDK 安装目录：$TOOLS_DIR/$TOOL_VERSION"
mkdir -p "$TOOLS_DIR"
cd "$TOOLS_DIR"

echo "🌐 Step 3: 下载 Android commandline tools..."
wget -O sdk-tools.zip "$SDK_ZIP_URL"

echo "📦 Step 4: 解压工具包..."
unzip sdk-tools.zip
rm sdk-tools.zip

echo "🔄 Step 5: 重命名目录为 $TOOL_VERSION（供 sdkmanager 识别）"
mv cmdline-tools "$TOOL_VERSION"

echo "✅ 工具下载与解压完成。"

# 添加环境变量到 shell 配置
echo "🔧 Step 6: 配置环境变量..."
ENV_CONFIG_FILE="$HOME/.bashrc"
if ! grep -q ANDROID_SDK_ROOT "$ENV_CONFIG_FILE"; then
  cat <<'EOF' >> "$ENV_CONFIG_FILE"

# >>> Android SDK 设置 >>>
export ANDROID_SDK_ROOT=$HOME/android-sdk
export PATH=$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH
export PATH=$ANDROID_SDK_ROOT/platform-tools:$PATH
export PATH=$ANDROID_SDK_ROOT/emulator:$PATH
# <<< Android SDK 设置 <<<
EOF
  echo "✅ 已添加到 $ENV_CONFIG_FILE。请运行 source $ENV_CONFIG_FILE 或重新打开终端以生效。"
else
  echo "⚠️ 已检测到 SDK 环境变量配置，未重复添加。"
fi

# 生效当前终端
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"
export PATH="$ANDROID_SDK_ROOT/emulator:$PATH"

echo "📄 Step 7: 接受 SDK License 条款..."
yes | sdkmanager --licenses

echo "⬇️ Step 8: 安装基础组件..."
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"

echo "🎉 所有步骤完成！你现在可以使用 adb / sdkmanager 等工具了。"

echo "✅ 示例："
echo "    adb --version"
echo "    sdkmanager --list"