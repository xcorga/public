#!/bin/bash
set -e

# 定义脚本信息数组
scripts=(
    "Linux配置远程桌面环境:install_desktop.sh"
    "Linux配置Android SDK开发环境:install_android_env.sh"
    "Linux安装或更新Android Studio:install_android_studio.sh"
    "Linux安装安卓15模拟器:install_emu.sh"
)

print_menu() {
    echo "请输入序号执行脚本（可多选，空格或逗号分隔，例如：0 2 3）："
    for i in "${!scripts[@]}"; do
        echo "$i --- ${scripts[$i]%%:*}"
    done
}

run_script() {
    local idx=$1
    if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#scripts[@]}" ]; then
        script_info="${scripts[$idx]}"
        script_name="${script_info%%:*}"
        script_file="${script_info#*:}"

        echo "执行脚本: $script_name"
        sudo /bin/bash -c "$(curl -fsSL "${prefix_url}${script_file}")"
    else
        echo "无效序号：'$idx'"
    fi
}

prefix_url="https://raw.githubusercontent.com/xcorga/public/refs/heads/main/script/shell/"

if [ -z "$1" ]; then
    print_menu
    read -r input
else
    input="$*"
fi

# 把逗号替换成空格，方便分割
input="${input//,/ }"

# 遍历所有输入的序号并执行对应脚本
for idx in $input; do
    run_script "$idx"
done