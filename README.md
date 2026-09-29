# Samsung SCX-4200 打印机 macOS 安装指南

本项目通过两个 Git tag 区分 macOS 版本。仓库名称不变，请先选择与系统匹配的 tag，
不要混用两个 tag 中的安装脚本和驱动文件。

## 先选择版本

| macOS | Apple Silicon | 使用版本 |
|---|---|---|
| 13–26 | Intel 或 Apple Silicon | `v1.0.0-macos-13-26-legacy` |
| 27+ | Apple Silicon | `v2.0.0-macos-27-native-arm64` |

- macOS 13–26 使用旧版 Samsung 驱动路径；Apple Silicon 需要 Rosetta 2。
- macOS 27+ Apple Silicon 使用 native arm64 QPDL 驱动，不需要 Rosetta 2。
- 本次 native 路径只覆盖打印，不覆盖扫描。

## macOS 27+ Apple Silicon：native 安装

```bash
git clone git@github.com:kami1983/scx-4200-macos-setup-for-sequoia-15.git
cd scx-4200-macos-setup-for-sequoia-15
git checkout v2.0.0-macos-27-native-arm64
sudo ./install_scx4200_native_driver.sh
```

安装脚本会检查 macOS 27+ 和 arm64，安装 SCX-4200 专用 PPD 以及原生
`rastertoqpdl`，并优先复用现有 `Samsung_SCX-4200` 队列的 USB 地址。

验证安装：

```bash
lpstat -p Samsung_SCX-4200
file /Library/Printers/QPDL/rastertoqpdl
lipo -archs /Library/Printers/QPDL/rastertoqpdl
cupstestppd -q /Library/Printers/QPDL/scx4200.ppd
echo "native SCX-4200 test" | lp -d Samsung_SCX-4200
```

native 过滤器的来源和 SHA-256 校验值见 [native/NOTICE.md](native/NOTICE.md)。

以下内容是 `v1.0.0-macos-13-26-legacy` 的旧版安装步骤，适用于 macOS 13–26。

> **验证日期**：2026-09-29
> **旧版核心思路**：绕过系统版本检查，手动提取三星官方驱动包中的 `SCX-4300` 驱动（与 SCX-4200 硬件通用）。

---

## 一、所需文件

| 文件名 | 说明 | 来源 |
|--------|------|------|
| `SamsungPrinterDrivers.dmg` | 三星官方打印机驱动包 v2.6 | 本文件夹已附带 | 如果没有尝试从 https://support.apple.com/zh-cn/106427 上面下载
| `install_scx4200_driver.sh` | 一键安装脚本（可选） | 本文件夹已附带 |

> **驱动包说明**：该 `.dmg` 内含 `SamsungPrinterDrivers.pkg`，官方标注仅支持 macOS 10.6 ~ 10.x。在 macOS 13/14/15 上直接双击安装会因版本检查失败而报错，需手动提取文件安装。

---

## 二、问题背景

### 2.1 为什么官方 pkg 装不上？

打开 `SamsungPrinterDrivers.pkg` 的 `Distribution` 文件可见以下版本检查逻辑：

```xml
<options hostArchitectures='ppc,i386'/>
function installationCheck() 
    if (system.compareVersions(system.version.ProductVersion, '10.6.1') >= 0 &&
        system.compareVersions(system.version.ProductVersion, '11.0') == -1) {
```

系统版本要求 **≥ 10.6.1 且 < 11.0**，macOS 15.x 直接被拒之门外。

### 2.2 为什么 Gutenprint 不行？

Gutenprint（CUPS+Gutenprint）是一款优秀的开源通用驱动，但 **v5.3.3 的驱动列表中没有 Samsung SCX-4200**，也没有同引擎的 ML-2010。经实际验证，在 `lpinfo -m` 的输出中无法找到匹配型号，故不适用。

### 2.3 为什么选 SCX-4300 驱动？

三星 `SamsungPrinterDrivers.pkg` 中**没有 SCX-4200 的独立驱动**，但有 `SCX-4300` 和 `SCX-4x24` 系列。根据大量社区实践，**SCX-4200 与 SCX-4300 打印引擎完全相同**，驱动完全通用。

---

## 三、手动安装步骤（推荐）

> 以下步骤已在 macOS 15.0 (x86_64, Rosetta 2) + Samsung SCX-4200 USB 直连环境下验证通过。

### 3.1 挂载驱动镜像

双击 `SamsungPrinterDrivers.dmg`，系统会自动挂载到 `/Volumes/Samsung Printer Drivers/`。

### 3.2 提取 pkg 内容

打开终端（Terminal），执行以下命令将安装包展开到临时目录：

```bash
pkgutil --expand "/Volumes/Samsung Printer Drivers/SamsungPrinterDrivers.pkg" /tmp/samsung_exp
```

提取后，驱动文件位于：

```
/tmp/samsung_exp/SamsungPrinterDrivers.pkg/Library/Printers/
├── PPDs/Contents/Resources/Samsung SCX-4300 Series.gz   ← PPD 文件
└── Samsung/
    ├── Filters/                                          ← CUPS 过滤器
    │   ├── commandtosec
    │   ├── prefilter
    │   ├── pstosecps
    │   ├── rastertosec
    │   ├── rastertosec2
    │   └── statusDesc.plist
    ├── PDEs/                                             ← 打印对话框扩展
    ├── Icons/                                            ← 图标
    └── SCX-4300/                                         ← 打印机型号配置
        ├── GrayHT_600
        └── Gray1D_600
```

> **注意**：如果只复制 PPD 文件而不复制 `Samsung/Filters/` 目录，添加打印机后打印时会报错：**"缺少打印机的软件"**。

### 3.3 复制驱动文件到系统目录

需要管理员权限。以下命令会弹出系统密码框：

```bash
osascript -e 'do shell script "
    mkdir -p /Library/Printers/PPDs/Contents/Resources/ && \
    mkdir -p /Library/Printers/Samsung && \
    cp -R /tmp/samsung_exp/SamsungPrinterDrivers.pkg/Library/Printers/PPDs/Contents/Resources/Samsung SCX-4300 Series.gz /Library/Printers/PPDs/Contents/Resources/ && \
    cp -R /tmp/samsung_exp/SamsungPrinterDrivers.pkg/Library/Printers/Samsung/* /Library/Printers/Samsung/ && \
    chown -R root:wheel /Library/Printers/Samsung && \
    chmod -R 755 /Library/Printers/Samsung
" with administrator privileges'
```

或使用 `sudo` 手动逐条执行：

```bash
sudo mkdir -p /Library/Printers/PPDs/Contents/Resources/
sudo mkdir -p /Library/Printers/Samsung

sudo cp -R "/tmp/samsung_exp/SamsungPrinterDrivers.pkg/Library/Printers/PPDs/Contents/Resources/Samsung SCX-4300 Series.gz" \
    /Library/Printers/PPDs/Contents/Resources/

sudo cp -R /tmp/samsung_exp/SamsungPrinterDrivers.pkg/Library/Printers/Samsung/* /Library/Printers/Samsung/

sudo chown -R root:wheel /Library/Printers/Samsung
sudo chmod -R 755 /Library/Printers/Samsung
```

### 3.4 重启 CUPS 打印服务

```bash
sudo killall cupsd
```

等待 5~10 秒，CUPS 会自动重启。

### 3.5 添加打印机

#### 方式 A：命令行添加（推荐）

```bash
lpadmin -p "Samsung_SCX-4200" \
    -D "Samsung SCX-4200 Series" \
    -L "Local" \
    -v "usb://Samsung/SCX-4200%20Series?serial=YOUR_SERIAL_HERE" \
    -P "/Library/Printers/PPDs/Contents/Resources/Samsung SCX-4300 Series.gz" \
    -E
```

> 请将 `YOUR_SERIAL_HERE` 替换为实际序列号。若不确定序列号，可执行 `system_profiler SPUSBDataType | grep -A 10 "SCX-4200"` 查看，或在 GUI 添加时自动识别。

#### 方式 B：图形界面添加

1. 打开 **系统设置 → 打印机与扫描仪**
2. 点击 **"+"** 号添加打印机
3. 选中自动识别出的 **Samsung SCX-4200 Series**
4. 在 **"使用"（Use）** 下拉菜单中选择 **"选择软件"（Select Software）**
5. 搜索框输入 `SCX-4300`，选中 **"Samsung SCX-4300 Series"**
6. 点击**"好"** → **"添加"**

---

## 四、一键安装脚本（可选）

本文件夹附带 `install_scx4200_driver.sh`，在终端中运行：

```bash
bash ~/Downloads/SCX-4200-macOS-Setup/install_scx4200_driver.sh
```

脚本会自动完成：挂载 dmg → 提取 pkg → 复制文件 → 添加打印机 → 重启 CUPS。

---

## 五、验证安装

### 5.1 检查打印机状态

```bash
lpstat -p
```

预期输出：
```
打印机Samsung_SCX-4200闲置，启用时间始于 ...
```

### 5.2 检查驱动选项是否加载

```bash
lpoptions -p Samsung_SCX-4200 -l
```

如果能正常列出纸张尺寸、省墨模式、对比度等选项，说明 PPD 和过滤器均工作正常。

### 5.3 打印测试页

打开 TextEdit 或 Safari，按 `Cmd+P`，选择 `Samsung_SCX-4200`，打印测试。

---

## 六、故障排除

| 现象 | 原因 | 解决方案 |
|------|------|---------|
| **"缺少打印机的软件"** | 只复制了 PPD，没复制 `Samsung/Filters/` | 重新执行 3.3 步骤，确保 Filters 目录完整复制 |
| **"Filter failed"** | 过滤器二进制文件权限不对或架构不兼容 | 检查 `sudo chown -R root:wheel /Library/Printers/Samsung` 和 `chmod -R 755` 是否执行 |
| **打印乱码** | 选错了驱动型号 | 务必选择 **Samsung SCX-4300 Series**，不要选 Generic PCL |
| **系统设置里看不到 SCX-4300 驱动** | PPD 文件未放入系统目录 | 确认 `/Library/Printers/PPDs/Contents/Resources/Samsung SCX-4300 Series.gz` 存在 |

---

## 七、扫描功能说明

Samsung SCX-4200 是多功能一体机（打印 + 扫描），但 **扫描驱动在本方案中无法使用**，原因如下：

1. 扫描组件依赖 `Samsung Scanner.app`（位于 `/Library/Image Capture/Devices/`），该应用包含 32 位代码。
2. macOS 10.15 (Catalina) 起已彻底移除 32 位支持。
3. 即使提取了扫描组件，在 macOS 13/14/15 上也无法被 Image Capture 识别。

**扫描替代方案**：
- iPhone / iPad 自带"备忘录"扫描功能
- Microsoft Lens、Scanner Pro 等 App
- 如有旧 Windows 电脑，可共享扫描仪使用

---

## 八、文件清单（归档备份）

```
SCX-4200-macOS-Setup/
├── SamsungPrinterDrivers.dmg      # 官方驱动镜像（v2.6）
├── install_scx4200_driver.sh      # 一键安装脚本
└── README.md                        # 本说明文档
```

建议将此文件夹保存到云盘或 U 盘，下次重装系统或换 Mac 时可直接复用。

---

## 九、技术备注

- **过滤器架构**：官方过滤器为 Universal Binary（i386 + x86_64），i386 部分在 macOS 10.15+ 已失效，但 **x86_64 部分可正常工作**。Apple Silicon Mac 需开启 Rosetta 2。
- **PPD 版本**：`cupsVersion: 1.4`，在 CUPS 2.x/3.x 下向后兼容。
- **Gatekeeper**：旧版驱动无 Apple 签名，复制到系统目录后若被系统阻止，需前往 **系统设置 → 隐私与安全性** 手动允许。

---

*文档整理完成，祝使用顺利。*
