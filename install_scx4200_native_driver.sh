#!/bin/bash
# Native Samsung SCX-4200 driver for macOS 27+ Apple Silicon.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
FILTER_SOURCE="$SCRIPT_DIR/native/bin/rastertoqpdl"
PPD_SOURCE="$SCRIPT_DIR/native/ppd/scx4200.ppd"
FILTER_DIR="/Library/Printers/QPDL"
FILTER_DEST="$FILTER_DIR/rastertoqpdl"
PPD_DEST="$FILTER_DIR/scx4200.ppd"
QUEUE="Samsung_SCX-4200"
EXPECTED_SHA256="9b4504271a6fe1eb8f69a7cd8b2573cd49e82cd484fe204b0902cff470bf7520"

if [ "$(id -u)" -ne 0 ]; then
    echo "请使用管理员权限运行：sudo $0" >&2
    exit 1
fi

MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=${MACOS_VERSION%%.*}
if ! [[ "$MACOS_MAJOR" =~ ^[0-9]+$ ]] || [ "$MACOS_MAJOR" -lt 27 ]; then
    echo "此 native tag 仅支持 macOS 27+，当前系统为 macOS $MACOS_VERSION。" >&2
    echo "请改用 v1.0.0-macos-13-26-legacy。" >&2
    exit 2
fi

ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
    echo "此 native tag 仅支持 Apple Silicon arm64，当前架构为 $ARCH。" >&2
    echo "请改用 v1.0.0-macos-13-26-legacy。" >&2
    exit 3
fi

if [ ! -f "$FILTER_SOURCE" ] || [ ! -f "$PPD_SOURCE" ]; then
    echo "native 驱动文件不完整，请确认当前 checkout 是 v2.0.0-macos-27-native-arm64。" >&2
    exit 4
fi

echo "正在校验 macOS 27 native 驱动资产..."
cupstestppd -q "$PPD_SOURCE"
FILTER_ARCHS=$(lipo -archs "$FILTER_SOURCE")
if [ "$FILTER_ARCHS" != "arm64" ]; then
    echo "native 过滤器架构错误：期望 arm64，实际为 $FILTER_ARCHS。" >&2
    exit 5
fi
FILTER_SHA256=$(shasum -a 256 "$FILTER_SOURCE" | awk '{print $1}')
if [ "$FILTER_SHA256" != "$EXPECTED_SHA256" ]; then
    echo "native 过滤器校验失败：SHA-256 不匹配。" >&2
    exit 6
fi

echo "正在安装 native 过滤器和 PPD..."
mkdir -p "$FILTER_DIR"
install -o root -g wheel -m 755 "$FILTER_SOURCE" "$FILTER_DEST"
install -o root -g wheel -m 644 "$PPD_SOURCE" "$PPD_DEST"

URI=$(lpstat -v "$QUEUE" 2>/dev/null | sed -n 's/^[^:]*: //p' | head -n 1)
if [ -z "$URI" ]; then
    URI=$(lpinfo -v 2>/dev/null | awk 'tolower($0) ~ /usb:/ && tolower($0) ~ /scx-4200/ {print $2; exit}')
fi
if [ -z "$URI" ]; then
    echo "没有发现 SCX-4200 USB 打印机。请连接并打开打印机后重新运行。" >&2
    exit 7
fi

echo "正在配置 CUPS 队列 $QUEUE..."
lpadmin -p "$QUEUE" \
    -D "Samsung SCX-4200 Series" \
    -L "Local" \
    -v "$URI" \
    -P "$PPD_SOURCE" \
    -E
cupsenable "$QUEUE"
cupsaccept "$QUEUE"

echo
echo "=== 安装完成 ==="
lpstat -p "$QUEUE"
echo "测试打印：echo 'Samsung SCX-4200 native tag test' | lp -d $QUEUE"
