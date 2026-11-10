# BakaSU × Driftwood

<p align="center"><strong>更纯粹的内核 · A More Pure Kernel</strong></p>

<p align="center">
  <img src="assets/banner.png" alt="BakaSU × Driftwood" width="100%">
</p>

<p align="center">
  <strong>BakaSU + SuSFS for Redmi K30 5G (picasso)</strong><br>
  基于 Driftwood 4.19.157，为 Redmi K30 5G 提供定制内核与内核级 Root 支持。
</p>

<p align="center">
  <a href="https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood/releases">
    <img src="https://img.shields.io/github/v/release/acgmnc/BakaSU-Redmi-K30-5G-Driftwood?style=flat-square&label=Release" alt="Latest release">
  </a>
  <a href="https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood">
    <img src="https://img.shields.io/github/stars/acgmnc/BakaSU-Redmi-K30-5G-Driftwood?style=flat-square" alt="GitHub stars">
  </a>
  <img src="https://img.shields.io/badge/Device-Redmi%20K30%205G-blue?style=flat-square" alt="Device">
  <img src="https://img.shields.io/badge/Kernel-4.19.157-orange?style=flat-square" alt="Kernel version">
  <img src="https://img.shields.io/badge/Root-BakaSU-red?style=flat-square" alt="Root solution">
  <img src="https://img.shields.io/badge/SuSFS-v2.3.0-8A2BE2?style=flat-square" alt="SuSFS version">
</p>

> **当前发布：** [BakaSU 35252 + SuSFS v2.3.0](https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood/releases/tag/v4.2.0-rc3-35252-susfs)。发布说明记录了 picasso 真机启动、Root 与 SuSFS 状态验证。

<details>
<summary>目录</summary>

- [项目简介](#项目简介)
- [项目信息](#项目信息)
- [功能特性](#功能特性)
- [设备适配与补丁](#设备适配与补丁)
- [下载](#下载)
- [构建指南](#构建指南)
- [刷入说明](#刷入说明)
- [管理器](#管理器)
- [常见问题](#常见问题)
- [已知限制](#已知限制)
- [免责声明](#免责声明)
- [致谢与许可证](#致谢与许可证)

</details>

## 项目简介

本项目基于 [HeinUmin/kernel_xiaomi_sm7250](https://github.com/HeinUmin/kernel_xiaomi_sm7250) 的 `android-4.19` 分支，面向 Redmi K30 5G（设备代号 `picasso`）进行适配。

主要工作包括：

- 将 BakaSU 集成到 Linux 4.19 内核。
- 移植并适配 SuSFS v2.3.0。
- 为旧内核补充兼容接口与头文件。
- 修复部分设备驱动问题。
- 提供自动化构建和 boot.img 重打包脚本。

**本项目仅面向 Redmi K30 5G。** 请勿将构建产物刷入其他设备；不同系统版本也应使用相匹配的镜像。

## 项目信息

| 项目 | 信息 |
| --- | --- |
| 目标设备 | Redmi K30 5G（`picasso`） |
| SoC | Qualcomm Snapdragon 765G（SM7250） |
| 基础内核 | Driftwood `4.19.157` |
| 上游源码 | [HeinUmin/kernel_xiaomi_sm7250](https://github.com/HeinUmin/kernel_xiaomi_sm7250) |
| 上游分支 | `android-4.19` |
| Root 方案 | BakaSU `v4.2.0-rc3-d5e9e025` |
| BakaSU Version Code | `35252` |
| SuSFS | `v2.3.0`（NON-GKI） |
| Hook 模式 | `KSU_SUSFS` inline hook |
| 推荐工具链 | Clang 15.0.7 + LLD 15.0.7 |

## 功能特性

### BakaSU

项目集成固定版本的 BakaSU 内核源码：

- 版本：`v4.2.0-rc3`
- Commit：`d5e9e025`
- Version Code：`35252`

源码快照由 `upstream.lock` 记录，以固定构建版本。

### SuSFS v2.3.0

基于 [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) 移植并适配 Linux 4.19。当前发布版本启用了以下 9 项功能：

| 配置 | 功能 |
| --- | --- |
| `SUS_PATH` | 隐藏指定路径 |
| `SUS_MOUNT` | 隐藏 su 进程创建的挂载信息（mountinfo、mounts、mountstats） |
| `SUS_KSTAT` | 伪装文件状态信息 |
| `SUS_MAP` | 隐藏指定进程的 maps、smaps、pagemap |
| `SPOOF_UNAME` | 伪装 uname 信息 |
| `SPOOF_CMDLINE_OR_BOOTCONFIG` | 伪装 `/proc/cmdline`（4.19 不使用 bootconfig） |
| `OPEN_REDIRECT` | 打开路径及读取链接重定向 |
| `ENABLE_LOG` | 启用 SuSFS 日志 |
| `HIDE_KSU_SUSFS_SYMBOLS` | 隐藏 KSU / SuSFS 符号 |

### 设备适配与补丁

项目还包含针对旧内核和目标设备的适配，例如修复 trace 头文件路径、补充 4.19 缺少的接口、修复摄像头驱动头文件搜索路径，以及为掌心传感器读取增加超时保护。

## 设备适配与补丁

默认构建使用 `patches/` 中的 `0002` 至 `0006` 补丁。构建脚本会按顺序应用补丁，并在失败时停止。

| 补丁 | 说明 |
| --- | --- |
| `0002-trace-include-paths.patch` | 修复 trace 头文件路径 |
| `0003-build-fixes.patch` | 修复摄像头头文件路径并调整 defconfig |
| `0004-headers-shims.patch` | 补充 4.19 缺少的兼容头文件 |
| `0005-palm-sensor-bounded-wait.patch` | 为掌心传感器读取增加超时，避免异常情况下无限等待 |
| `0006-susfs-v2.3.0-4.19.patch` | SuSFS v2.3.0 的 4.19 适配补丁 |

`0001-bakasu-manual-hooks.patch` 位于 `patches/manual-hooks/`，属于可选手动 Hook 模式，**默认构建不会应用**；不要与 `0006` 同时应用。

## 下载

正式构建版本通过 [GitHub Releases](https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood/releases) 发布。

<p align="center">
  <a href="https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood/releases/tag/v4.2.0-rc3-35252-susfs">
    <img src="https://img.shields.io/badge/下载当前版本-GitHub%20Releases-red?style=for-the-badge&logo=github" alt="Download current release">
  </a>
</p>

| 发布格式 | 用途 |
| --- | --- |
| AnyKernel3 ZIP | 在兼容的 Recovery 中刷入；通常保留设备当前 ramdisk |
| `boot.img` | 通过 Fastboot 刷入；必须与当前系统及 ramdisk 匹配 |

下载前请核对版本、设备型号和 Android 版本。

## 构建指南

### 环境要求

推荐使用 Ubuntu 或 WSL2 Ubuntu。项目测试工具链为 Clang 15.0.7 和 LLD 15.0.7。

主要依赖：

- Clang 15、LLD 15、LLVM 15
- AArch64 GNU Toolchain
- Python 3、Git、Make
- 常用内核构建依赖

Ubuntu 安装示例：

~~~bash
sudo apt update
sudo apt install -y \
  build-essential bc bison flex \
  libssl-dev libelf-dev libncurses-dev \
  python3 git zip unzip rsync cpio kmod \
  binutils-aarch64-linux-gnu gcc-aarch64-linux-gnu \
  clang-15 lld-15 llvm-15
~~~

如果 LLVM 工具安装在带版本号的目录中，请将对应目录加入 `PATH`，并确认可以找到 `clang`、`ld.lld` 及其他 LLVM 工具。

### 开始构建

~~~bash
git clone https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood.git
cd BakaSU-Redmi-K30-5G-Driftwood
./build.sh
~~~

构建脚本会自动拉取基础内核源码、应用默认补丁、集成 BakaSU、配置内核并编译 `Image` 与 `dtbo.img`，随后收集 DTB 并整理产物。指定原厂 boot.img 时，还会生成重打包镜像。

### 自定义构建参数

~~~bash
# 复用已经准备好的内核源码树
KSRC=/path/to/kernel ./build.sh

# 指定 Clang 工具链目录
TC=/path/to/clang/bin ./build.sh

# 使用原厂 boot.img 额外生成重打包镜像
URL_BOOT=stock_boot.img ./build.sh
~~~

### 构建产物

默认产物位于 `build/out/`：

~~~text
build/out/
├── Image
├── dtb/
├── dtbo.img
└── boot.img   # 仅在指定 URL_BOOT 时生成
~~~

## 刷入说明

### 方式一：AnyKernel3 ZIP

1. 下载与设备及系统版本匹配的 AnyKernel3 ZIP。
2. 将设备启动到兼容的 Recovery。
3. 选择 ZIP 并执行刷入。
4. 刷入完成后重启设备。

该方式适合希望保留当前 ramdisk 的用户，但仍需确认发布包适用于自己的系统版本。

### 方式二：boot.img

仅在能够确认镜像与设备、Android 版本及 ramdisk 匹配时使用：

~~~bash
fastboot flash boot boot.img
fastboot reboot
~~~

刷入前请备份原厂 boot.img，并确认能够通过 Fastboot 或 Recovery 恢复设备。

> **Ramdisk 提醒：**Android 12 与 Android 13 的原厂 ramdisk 不通用。仓库记录的 `boot_bakasu_susfs.img` 使用 Android 13 原厂 ramdisk；Android 12 用户应选择匹配版本的 AnyKernel3 包，或使用自己的 Android 12 原厂 boot.img 重打包。其他系统版本优先使用适配的 AnyKernel3 包。

## 管理器

项目使用 BakaSU / ReSukiSU 管理器。管理器 APK 不由本仓库的内核构建脚本生成，请从对应上游发布渠道获取。

| 项目 | 信息 |
| --- | --- |
| 管理器 | BakaSU / ReSukiSU |
| 版本 | `v4.2.0-rc3` |
| 包名 | `com.resukisu.resukisu` |
| 架构 | `arm64-v8a` |

管理器版本和内核驱动版本是独立信息，不要求版本号完全相同；建议使用与 BakaSU 驱动接口相匹配的管理器。

## 常见问题

**这个内核支持哪些设备？**  
目前仅面向 Redmi K30 5G（`picasso`）适配，请勿刷入其他设备。

**Android 12、13 或其他版本可以使用吗？**  
请根据系统版本选择匹配的镜像。直接重打包的 boot.img 必须使用对应系统版本的原厂 ramdisk；通常更适合使用经过适配的 AnyKernel3 包。

**为什么刷入后还需要安装管理器？**  
内核提供 Root 所需的内核接口，管理器负责用户侧的授权与管理功能，两者配合使用。

**可以使用其他 KernelSU 管理器吗？**  
建议优先使用与本项目 BakaSU 驱动版本匹配的管理器，避免接口差异导致功能异常。

**AnyKernel3 ZIP 和 boot.img 应该选哪个？**  
不熟悉 Fastboot 或 ramdisk 匹配时，优先选择适配当前系统的 AnyKernel3 ZIP。只有确认镜像与系统匹配时再直接刷入 boot.img。

## 已知限制

- 工具链：项目记录显示 Clang 15 构建在目标设备上的稳定性较好；Clang 17 曾在 modem 初始化阶段出现崩溃。
- Ramdisk：Android 12 与 Android 13 的原厂 ramdisk 不可互换。
- Android 16：使用 `4.19.325-cip134` 内核的 picasso ROM 与本项目的 `4.19.157` 基线不兼容，需要基于对应内核源码重新移植。
- SuSFS：当前版本针对 4.19 适配并启用了上表所列功能；其他功能不保证可用。
- `OPEN_REDIRECT`：目前未覆盖 `O_TMPFILE` 路径。

## 免责声明

- 本项目仅供学习、研究与技术交流使用。
- 解锁 Bootloader、刷入第三方内核或修改系统都存在风险。
- 刷入不匹配的镜像可能导致设备无法启动或数据丢失。
- 使用者应自行确认设备型号、系统版本和镜像兼容性，并提前准备恢复方案。
- 作者不对因使用本项目造成的数据丢失、设备损坏或其他后果承担责任。

## 致谢与许可证

感谢以下项目及贡献者：

- [HeinUmin/kernel_xiaomi_sm7250](https://github.com/HeinUmin/kernel_xiaomi_sm7250)
- [Baka-SU/BakaSU](https://github.com/Baka-SU/BakaSU)
- [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)
- Driftwood 内核相关贡献者
- Redmi K30 5G 社区、测试者，以及 Claude 和 ChatGPT

内核主体及第三方组件遵循各自源码目录中的许可证。使用、修改或再分发时，请遵守对应上游项目的许可证要求。
