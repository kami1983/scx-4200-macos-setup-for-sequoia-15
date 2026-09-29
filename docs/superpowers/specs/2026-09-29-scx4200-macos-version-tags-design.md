# Samsung SCX-4200 macOS 版本 tag 方案设计

日期：2026-09-29  
状态：待实施

## 1. 背景

当前项目最初针对 macOS 13/14/15，依赖 Samsung 旧版驱动包中的 Intel
CUPS 过滤器，并通过 Rosetta 在 Apple Silicon 上运行。升级到当前 macOS
27 后，该路径会遇到过滤器架构和打印数据发送问题。

本机已验证另一条可工作的路径：使用 SCX-4200 专用 PPD 和原生 arm64
`rastertoqpdl` QPDL 过滤器，CUPS 打印任务能够完成并发送非零数据。

## 2. 已确认的目标

项目保留同一个 GitHub 仓库，通过两个 tag 明确区分 macOS 版本，不在安装
脚本中加入跨版本自动切换。

| tag | 适用范围 | 驱动路径 |
| --- | --- | --- |
| `v1.0.0-macos-13-26-legacy` | macOS 13–26，及需要旧 Samsung 包的环境 | 保留当前 DMG、旧版 Samsung 过滤器和现有安装流程 |
| `v2.0.0-macos-27-native-arm64` | macOS 27+ Apple Silicon | SCX-4200 专用 PPD + 原生 arm64 QPDL 过滤器，不依赖 Rosetta |

旧 tag 必须指向当前可回退的原始提交；新 tag 在此基础上增加 macOS 27
路径。仓库名称不变。

## 3. 方案比较

### 方案 A：两个 tag 对应两个稳定快照（采用）

旧 tag 保持原项目内容，新 tag 增加独立的 native 安装资产和安装脚本。
用户根据系统版本选择 tag，再运行对应脚本。

优点：版本边界清晰、旧环境回退简单、每个安装路径都能单独测试。缺点是
用户需要先选择正确的 tag。

### 方案 B：一个脚本自动检测 macOS 并切换驱动

将两个路径合并到一个安装脚本中，根据系统版本和 CPU 架构自动选择。

优点是入口少；缺点是旧路径和新路径耦合，容易把新系统的修复回溯影响到
旧系统，也会让 tag 的兼容性承诺不够明确。本次不采用。

### 方案 C：安装时从源码构建过滤器

不提交预编译过滤器，由用户在安装时下载并构建 SpliX。

优点是二进制可复现；缺点是依赖 Xcode Command Line Tools、编译工具和
网络，安装失败面明显更大。本次面向恢复可用性，不采用安装时构建作为主
路径；如保留构建脚本，只作为开发/复现辅助。

## 4. 设计细节

### 4.1 旧版本 tag

- `v1.0.0-macos-13-26-legacy` 直接指向当前原始提交。
- 不重写旧脚本，不替换其中的 Samsung DMG、SCX-4300 PPD 或旧过滤器。
- README 增加版本选择说明时，不能改变旧 tag 中已经存在的安装步骤。

### 4.2 macOS 27 native tag

新 tag 增加独立的 native 资产目录和安装脚本，至少包含：

- 精确声明 `Samsung SCX-4200` 的 PPD；
- 已验证为 Mach-O `arm64` 的 `rastertoqpdl`；
- 二进制来源、许可证说明和 SHA-256 校验值；
- 针对 macOS 27+ Apple Silicon 的安装说明和验证命令。

native 安装脚本的行为：

1. 在执行安装前检查 macOS 主版本和 CPU 架构，错误 tag 时给出明确提示并
   退出，不静默安装旧驱动。
2. 安装过滤器和 PPD 到项目约定的 `/Library/Printers/QPDL/` 目录。
3. 保留队列名 `Samsung_SCX-4200`，优先复用已有队列的 USB URI；没有已有
   队列时自动发现 SCX-4200 USB URI，不再依赖本机硬编码序列号。
4. 让队列使用 SCX-4200 专用 PPD 和 native QPDL 过滤器。
5. 安装后运行 PPD 校验、队列状态校验和过滤器架构校验，并打印下一步的
   一页测试命令。

安装脚本只处理打印，不把扫描工具或与本次修复无关的功能一并引入。

### 4.3 README 结构

README 顶部提供版本选择表，明确说明：

- macOS 13–26 使用旧 tag；
- macOS 27+ Apple Silicon 使用 native tag；
- tag 是安装入口，不需要用户自行混合两个版本的脚本和资产；
- native 路径不需要安装 Rosetta；
- 如何用 `lpstat`、`file`/`lipo`、`cupstestppd` 和 `lp` 验证安装。

## 5. 测试和验收标准

### 不依赖实体打印机的自动检查

- 两个安装脚本通过 `bash -n`。
- native PPD 通过 `cupstestppd -q`。
- native 过滤器是 Mach-O arm64，并且不是只包含 x86_64 的旧过滤器。
- native PPD 的产品/型号是 SCX-4200，过滤器指向 native QPDL 过滤器。
- native 脚本不包含旧的 SCX-4300 队列或 `rastertosec` 路径。
- tag 指向关系和工作树状态可由 Git 命令复核。

### 本机验收

- 安装后队列存在、启用且接受任务。
- 提交一页打印任务后，任务进入 completed，CUPS 日志没有 bad-architecture
  或 send-zero-bytes 错误。
- 真实打印机输出页面；这一步不能仅由静态检查替代。

## 6. 非目标

- 不重命名 GitHub 仓库。
- 不删除旧 tag 或旧安装方式。
- 不把扫描功能作为本次 macOS 27 兼容性升级的一部分。
- 不在本次工作中自动 push 到 GitHub；本地 commit 和 tag 完成后单独报告，
  是否 push 由用户决定。

