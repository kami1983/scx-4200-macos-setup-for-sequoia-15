#!/bin/bash
# Samsung SCX-4200 驱动手动安装脚本
# 原理：从已下载的 SamsungPrinterDrivers.pkg 中提取 SCX-4300 驱动文件
# SCX-4300 与 SCX-4200 硬件通用

set -e

PKG_EXTRACT="/tmp/samsung_pkg/exp/SamsungPrinterDrivers.pkg/Library/Printers"
DMG_MOUNT="/Volumes/Samsung Printer Drivers"

echo "=== Samsung SCX-4200 驱动安装脚本 ==="
echo ""

# 如果之前没有解压过 pkg，先解压
if [ ! -d "$PKG_EXTRACT" ]; then
    echo "正在解压驱动包..."
    mkdir -p /tmp/samsung_pkg
    pkgutil --expand "$DMG_MOUNT/SamsungPrinterDrivers.pkg" /tmp/samsung_pkg/exp
fi

echo "正在复制驱动文件到系统目录（需要管理员密码）..."

# 创建目录
sudo mkdir -p /Library/Printers/PPDs/Contents/Resources/
sudo mkdir -p /Library/Printers/Samsung

# 复制 PPD 文件（SCX-4300 与 SCX-4200 通用）
sudo cp -R "$PKG_EXTRACT/PPDs/Contents/Resources/Samsung SCX-4300 Series.gz" /Library/Printers/PPDs/Contents/Resources/

# 复制 Samsung 驱动文件（过滤器、PDE 扩展、图标、型号配置）
sudo cp -R "$PKG_EXTRACT/Samsung/" /Library/Printers/

# 设置正确权限
sudo chown -R root:wheel /Library/Printers/Samsung
sudo chmod -R 755 /Library/Printers/Samsung

echo ""
echo "驱动文件已安装。正在添加打印机..."

# 使用 lpadmin 添加 SCX-4200 打印机
sudo lpadmin -p "Samsung_SCX-4200" \
    -D "Samsung SCX-4200 Series" \
    -L "Local" \
    -v "usb://Samsung/SCX-4200%20Series?serial=8T40BABQ321796D." \
    -P "/Library/Printers/PPDs/Contents/Resources/Samsung SCX-4300 Series.gz" \
    -E

# 设为默认打印机（可选）
# sudo lpoptions -d Samsung_SCX-4200

echo ""
echo "=== 安装完成 ==="
echo "打印机 'Samsung_SCX-4200' 已添加。"
echo ""
echo "请打开 系统设置 > 打印机与扫描仪 查看。"
echo "建议打印测试页验证是否正常。"
echo ""
echo "注意：扫描功能需要另外安装 Image Capture 驱动，"
echo "但老扫描仪在 macOS 15 上大概率无法工作，建议用手机扫描App替代。"
