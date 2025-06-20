#!/bin/bash
set -e

# 定义脚本信息数组
scripts=(
    "Linux配置远程桌面环境:install_desktop.sh"
    "Linux配置Android SDK开发环境:install_android_env.sh"
    "Linux安装或更新Android Studio:install_android_studio.sh"
)

if [ -z "$1" ]; then
    echo "请输入序号执行脚本"
    for i in "${!scripts[@]}"; do
        echo "$i--- ${scripts[$i]%%:*}"
    done
    read index
else
    index="$1"
fi


prefix_url="https://raw.githubusercontent.com/xcorga/public/refs/heads/main/script/shell/"

if [ "$index" -ge 0 ] && [ "$index" -lt "${#scripts[@]}" ]; then
    # 获取脚本信息
    script_info="${scripts[$index]}"
    
    # 提取脚本名称和文件名
    script_name="${script_info%%:*}"
    script_file="${script_info#*:}"

    echo "执行脚本: $script_name"
    sudo /bin/bash -c "$(curl -fsSL "${prefix_url}${script_file}")"
else 
    echo "没找到'$index'对应的操作"
fi
