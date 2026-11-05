BakaSU × Driftwood

更纯粹的内核 · A More Pure Kernel

<p align="center">
  <img src="assets/banner.png" alt="BakaSU × Driftwood Banner" width="100%">
</p><p align="center">
  <strong>BakaSU + SuSFS for Redmi K30 5G (picasso)</strong>
</p><p align="center">
  <a href="https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood/releases">
    <img src="https://img.shields.io/github/v/release/acgmnc/BakaSU-Redmi-K30-5G-Driftwood?style=flat-square&label=Release" alt="Latest Release">
  </a>
  <a href="https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood">
    <img src="https://img.shields.io/github/stars/acgmnc/BakaSU-Redmi-K30-5G-Driftwood?style=flat-square" alt="GitHub Stars">
  </a>
  <img src="https://img.shields.io/badge/Device-Redmi%20K30%205G-blue?style=flat-square" alt="Device">
  <img src="https://img.shields.io/badge/Kernel-4.19.157-orange?style=flat-square" alt="Kernel Version">
  <img src="https://img.shields.io/badge/Root-BakaSU-red?style=flat-square" alt="BakaSU">
</p>一个面向 Redmi K30 5G 的定制 Linux 内核项目。基于 Driftwood 4.19 内核，集成 BakaSU，并移植 SuSFS v2.3.0，致力于在旧内核平台上提供更完整的内核级 Root 体验。

---

项目简介 | About

本项目基于 "HeinUmin/kernel_xiaomi_sm7250" (https://github.com/HeinUmin/kernel_xiaomi_sm7250) 的 "android-4.19" 分支，面向 Redmi K30 5G（"picasso"）进行适配。

项目主要工作包括：

- 将 BakaSU 集成到 Linux 4.19 内核。
- 移植并适配 SuSFS v2.3.0。
- 为旧内核补充必要的兼容性代码与头文件。
- 修复部分设备驱动问题。
- 提供自动化构建与 boot.img 重打包脚本。

本项目不是通用内核，构建产物仅针对目标设备及相应固件环境，不同的环境请自测。

项目信息 | Project Information

项目| 信息
目标设备| Redmi K30 5G
设备代号| "picasso"
SoC| Qualcomm Snapdragon 765G
基础内核| Driftwood
上游源码| "HeinUmin/kernel_xiaomi_sm7250"
上游分支| "android-4.19"
Linux 内核版本| "4.19.157"
Root 方案| BakaSU
BakaSU 版本| "v4.2.0-rc3-d5e9e025"
BakaSU Version Code| "35252"
SuSFS 版本| "v2.3.0"
推荐工具链| Clang 15.0.7 + LLD 15.0.7

功能特性 | Features

BakaSU

项目集成 BakaSU 内核源码，版本固定为：

- Version: "v4.2.0-rc3"
- Commit: "d5e9e025"
- Version Code: "35252"

源码快照通过 "upstream.lock" 记录，避免因上游更新导致构建版本信息发生变化。

SuSFS v2.3.0

基于 "simonpunk/susfs4ksu" (https://gitlab.com/simonpunk/susfs4ksu) 的实现进行 4.19 适配。

目前启用的功能：

配置| 功能
"SUS_PATH"| 隐藏指定路径
"SUS_KSTAT"| 伪装文件状态信息
"SUS_MAP"| 隐藏指定进程的 maps 等信息
"SPOOF_UNAME"| uname 信息伪装
"ENABLE_LOG"| SuSFS 日志
"HIDE_KSU_SUSFS_SYMBOLS"| 隐藏 KSU / SuSFS 符号

暂未启用的功能：

- "SUS_MOUNT"
- "OPEN_REDIRECT"
- "SPOOF_CMDLINE"

这些功能涉及较大的内核版本差异，暂不在当前 4.19 适配范围内。

设备适配与修复

项目包含多项针对旧内核的适配补丁：

- 修复部分 trace 头文件路径。
- 补充 5.x 内核中使用、但 4.19 缺少的头文件接口。
- 修复摄像头驱动编译时的头文件搜索路径。
- 为触摸屏掌心传感器读取增加超时，避免异常情况下无限等待导致的软重启。

内核补丁 | Patches

补丁位于 "patches/"，构建脚本会按文件名顺序应用。

补丁| 内容
"0001-bakasu-manual-hooks.patch"| BakaSU Hook 相关内核源码修改，并移除部分旧 KernelSU Hook
"0002-trace-include-paths.patch"| 修复 trace 头文件路径
"0003-build-fixes.patch"| 修复摄像头头文件路径并调整 defconfig
"0004-headers-shims.patch"| 补充旧内核缺少的头文件兼容层
"0005-palm-sensor-bounded-wait.patch"| 修复掌心传感器无限等待问题
"0006-susfs-v2.3.0-4.19.patch"| SuSFS v2.3.0 的 4.19 适配补丁

下载 | Download

所有正式构建版本均通过 GitHub Releases 发布。

<p align="center">
  <a href="https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood/releases">
    <img src="https://img.shields.io/badge/Download-GitHub%20Releases-red?style=for-the-badge&logo=github" alt="Download Releases">
  </a>
</p>项目同时提供两种发布格式：

文件类型| 说明| 推荐场景
AnyKernel3 ZIP| 通过兼容的 Recovery 刷入| 普通用户、希望保留当前 ramdisk 的用户
boot.img| 通过 Fastboot 直接刷入| 熟悉 Fastboot 操作的用户

下载时请确认版本、设备型号及 Android 版本，避免刷入不匹配的镜像。

构建指南 | Build

环境要求

推荐使用 Ubuntu 环境。

主要依赖：

- Clang 15
- LLD 15
- LLVM 15
- AArch64 GNU Toolchain
- Python 3
- Git
- Make
- 常用内核编译依赖

安装依赖：

sudo apt update

sudo apt install -y \
  build-essential bc bison flex \
  libssl-dev libelf-dev libncurses-dev \
  python3 git zip unzip rsync cpio kmod \
  binutils-aarch64-linux-gnu \
  gcc-aarch64-linux-gnu \
  clang-15 lld-15 llvm-15

如果系统中只有带版本后缀的 LLVM 工具，可以根据实际安装路径配置 "PATH"，确保构建脚本能够找到 "clang"、"ld.lld" 和相关 LLVM 工具。

开始构建

克隆仓库：

git clone https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood.git

cd BakaSU-Redmi-K30-5G-Driftwood

执行构建：

./build.sh

脚本会自动完成：

1. 拉取基础内核源码。
2. 应用项目补丁。
3. 安装 BakaSU 内核源码。
4. 配置内核。
5. 编译 Image 与 dtbo.img。
6. 收集 DTB 并整理构建产物。

自定义构建参数

复用已有内核源码：

KSRC=/path/to/kernel ./build.sh

指定 Clang 工具链目录：

TC=/path/to/clang/bin ./build.sh

使用原厂 boot.img 额外生成重打包镜像：

URL_BOOT=stock_boot.img ./build.sh

构建产物

构建产物位于：

build/out/
├── Image
├── dtb
├── dtbo.img
└── boot.img  # 仅在指定 URL_BOOT 时生成

刷入说明 | Installation

方式一：AnyKernel3

1. 下载对应版本的 AnyKernel3 ZIP。
2. 将设备启动至兼容的 Recovery。
3. 选择 ZIP 刷机包并执行刷入。
4. 刷入完成后重启设备。

该方式保留设备原有 ramdisk，适合希望沿用当前启动环境的用户。

方式二：boot.img

1. 下载与当前系统版本匹配的 boot.img。
2. 将设备进入 Fastboot 模式。
3. 连接电脑并执行：

fastboot flash boot boot_bakasu_35252.img
fastboot reboot

刷入前请务必备份原厂 boot.img，并确认镜像对应自己的系统版本。

注意：

- 当前提供的 "boot_bakasu_35252.img" 使用 Android 13 原厂 ramdisk。
- Android 12 与 Android 13 的原厂 ramdisk 不应混用。
- 如果使用 Android 12，请优先选择对应版本的 AnyKernel3 包，或自行使用 Android 12 原厂 boot.img 重打包。
- 刷入前请确认设备处于可恢复状态，并了解 Fastboot / Recovery 救援方式。

管理器 | Manager

项目使用 BakaSU / ReSukiSU 管理器。

管理器 APK 不随内核源码一同构建，需从对应上游发布渠道获取。

当前项目记录的管理器信息：

项目| 信息
管理器| BakaSU / ReSukiSU
版本| "v4.2.0-rc3"
包名| "com.resukisu.resukisu"
架构| "arm64-v8a"

注意：管理器版本与内核驱动版本是两个不同的版本信息，不需要完全相同。

常见问题 | FAQ

Q: 这个内核支持哪些设备？

目前仅面向 Redmi K30 5G（"picasso"）适配。请勿将其刷入其他设备。

Q: Android 12 和 Android 13 等等 都能使用吗？

请根据系统版本选择匹配的镜像。尤其是直接重打包的 boot.img，需要使用对应 Android 版本的原厂 ramdisk，推荐使用ak3刷入，这样不会破坏ramdisk。

Q: 为什么刷入后需要安装管理器？

内核负责提供 Root 所需的内核接口，管理器则负责用户侧的管理功能。两者需要配合使用。

Q: 可以直接使用其他 KernelSU 管理器吗？

建议优先使用与本项目 BakaSU 内核驱动相匹配的管理器版本，避免因接口或版本差异导致功能异常。

Q: AnyKernel3 和 boot.img 应该选哪个？

如果不熟悉 Fastboot 操作，建议选择 AnyKernel3；如果熟悉 Fastboot 并能确认 ramdisk 与系统版本匹配，也可以选择 boot.img。

已知问题 | Known Issues

- 工具链版本： 项目记录显示，Clang 15 编译的内核在目标设备上稳定性较好；Clang 17 曾出现 modem 初始化阶段崩溃的问题。
- Ramdisk 兼容性： Android 12 与 Android 13 的原厂 ramdisk 不通用。
- SuSFS 功能： 当前仅启用经过适配的部分功能，其余功能尚未完成 4.19 适配。

更新日志 | Changelog

项目版本更新记录请以 "GitHub Releases" (https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood/releases) 为准。

每次发布建议注明：

- 内核版本与构建日期。
- BakaSU 版本及 Commit。
- SuSFS 版本与启用功能。
- 修复的问题和新增功能。
- 适用的 Android 版本。
- 对应的刷入包及镜像类型。

免责声明 | Disclaimer

- 本项目仅供学习、研究与技术交流使用。
- 解锁 Bootloader、刷入第三方内核及修改系统均存在风险。
- 刷入不正确的镜像可能导致设备无法正常启动，甚至需要通过 Fastboot 或其他方式恢复。
- 使用者应自行确认设备型号、系统版本和镜像兼容性。
- 作者不对因使用本项目造成的数据丢失、设备损坏或其他后果承担责任。

致谢 | Credits

感谢以下项目及其贡献者：

- "HeinUmin/kernel_xiaomi_sm7250" (https://github.com/HeinUmin/kernel_xiaomi_sm7250)
- "Baka-SU/BakaSU" (https://github.com/Baka-SU/BakaSU)
- "simonpunk/susfs4ksu" (https://gitlab.com/simonpunk/susfs4ksu)
- Driftwood 内核相关贡献者
- Redmi K30 5G 社区及所有测试者

License

内核主体及各个第三方组件遵循各自源码目录中的许可证。使用、修改或再分发时，请遵守对应上游项目的许可证要求。
