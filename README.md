#                              BakaSU × Driftwood

<p align="center"><strong>更纯粹的内核 · A More Pure Kernel</strong></p>

<p align="center">
  <img src="assets/banner.png" alt="BakaSU × Driftwood" width="100%">
</p>

<p align="center">
  <strong>BakaSU + SuSFS for Redmi K30 5G (picasso)</strong><br>
  基于 4.19.325-cip133，为 Redmi K30 5G 提供定制内核与内核级 Root 支持。<br>
  <em>注：已不再使用Driftwood，但名称将保留（改名太麻烦）</em>
</p>

<p align="center">
  <a href="https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood/releases">
    <img src="https://img.shields.io/github/v/release/acgmnc/BakaSU-Redmi-K30-5G-Driftwood?style=flat-square&label=Release" alt="Latest release">
  </a>
  <a href="https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood">
    <img src="https://img.shields.io/github/stars/acgmnc/BakaSU-Redmi-K30-5G-Driftwood?style=flat-square" alt="GitHub stars">
  </a>
  <img src="https://img.shields.io/badge/Device-Redmi%20K30%205G-blue?style=flat-square" alt="Device">
  <img src="https://img.shields.io/badge/Kernel-4.19.325-green?style=flat-square" alt="Kernel version">
  <img src="https://img.shields.io/badge/Root-BakaSU-red?style=flat-square" alt="Root solution">
  <img src="https://img.shields.io/badge/SuSFS-v2.3.0-8A2BE2?style=flat-square" alt="SuSFS version">
</p>

> **当前版本：** Driftwood `V4.1.0`（`4.19.325-Driftwood-V4.1.0`），在 V4.0.0 基础上加入 **Android 16 (QPR2 / 25Q2+) 兼容**。发布说明记录了 picasso 真机在 HyperOS 2.0、RisingOS、PixelOS 上的启动、Root 与 SuSFS 状态验证。

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

本项目基于 [Akitlove/android_kernel_xiaomi_sm7250](https://github.com/Akitlove/android_kernel_xiaomi_sm7250) 的 `4.19.325-cip133` 源码（commit `da42a2f`），面向 Redmi K30 5G（设备代号 `picasso`）进行适配。

主要工作包括：

- 将 BakaSU 集成到 Linux 4.19 内核，并修复 KernelSU 在 4.19 上的 `filename` ABI 问题。
- 集成并适配 SuSFS v2.3.0。
- 为 Android 16 (QPR2 / 25Q2+) 补齐 BTF 与内核版本兼容，使 picasso 可以运行较新的 A16 ROM。
- 修复部分设备驱动问题（触摸传感器异常等待、编译器版本串解析等）。
- 提供自动化构建、boot.img 重打包与 AnyKernel3 打包流程。

**本项目仅面向 Redmi K30 5G。** 请勿将构建产物刷入其他设备；不同系统版本也应使用相匹配的镜像。

> 旧版 4.19.157 (HeinUmin) 基线的构建与补丁保留在 `legacy-4.19.157` 分支，与本分支补丁不通用。

## 项目信息

| 项目 | 信息 |
| --- | --- |
| 目标设备 | Redmi K30 5G（`picasso`） |
| SoC | Qualcomm Snapdragon 765G（SM7250） |
| 基础内核 | Driftwood `4.19.325-cip133` |
| 上游源码 | [Akitlove/android_kernel_xiaomi_sm7250](https://github.com/Akitlove/android_kernel_xiaomi_sm7250) |
| 基础内核 commit | `da42a2f`（由 `upstream.lock` 固定）|
| Root 方案 | BakaSU `v4.2.0-rc3-d5e9e025` |
| BakaSU Version Code | `35252` |
| SuSFS | `v2.3.0`（NON-GKI） |
| 推荐工具链 | ZyC Clang 23.0.0git + LLD 23 |

## 功能特性

### BakaSU

项目集成固定版本的 BakaSU 内核源码（位于 `kernel/`，构建时安装到内核树的 `KernelSU/kernel`）：

- 版本：`v4.2.0-rc3`
- Commit：`d5e9e025`
- Version Code：`35252`

BakaSU 与基础内核源码快照均由 `upstream.lock` 记录，构建脚本会检出其中锁定的上游内核 commit。

### SuSFS v2.3.0

基于 [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) 移植并适配 Linux 4.19。当前版本启用以下 9 项功能：

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

### 适配亮点

V4.1.0 针对 Android 16 与设备驱动做了以下适配：

- **BTF 兼容**：允许零长度 `DATASEC`，修复 Android 16 `netbpfload` 的 `BPF_BTF_LOAD` EINVAL。
- **内核版本兼容**：仅对 uid 0 进程伪装 `uname` 为 `5.4.x`，通过 `netbpfload` 的 `25Q2` 门槛并避免 `netd` 在 4.19 上 SIGABRT；普通应用仍看到真实版本。
- **触摸驱动**：`palm_sensor`、`p_sensor` 的 sysfs 读取改为 500 ms 超时，避免 I2C 异常时 SensorService 挂死触发软重启。
- **版本串**：修正编译器版本串格式，使 HyperOS 的「内核版本」能正常显示。

## 设备适配与补丁

默认构建使用 `patches/` 中的补丁（按顺序应用，失败即停止）：

| 补丁 | 说明 |
| --- | --- |
| `0001-driftwood-v4.0.0-base.patch` | 上游 `da42a2f` → 可用树的完整源码差异：SuSFS v2.3.0 集成、KSU `filename` ABI 修复、trace 头路径、缺失头文件 shim |
| `0005-palm-sensor-bounded-wait.patch` | 为掌心传感器读取增加 500 ms 超时，避免无限等待 |
| `0007-p-sensor-bounded-wait.patch` | 为接近传感器读取增加同样的超时保护 |
| `0008-strip-compiler-urls.patch` | 修正编译器版本串，修复 HyperOS「内核版本 Unavailable」 |
| `0009-btf-allow-zero-size-datasec.patch` | 允许零长度 `DATASEC`，修复 Android 16 的 `BPF_BTF_LOAD` 失败 |
| `0010-per-proc-uname-spoof.patch` | 仅 uid 0 进程报告 `5.4.210`，兼容 Android 16 的 `netbpfload` / `netd` |

`legacy-4.19.157` 分支保留旧的 `0002`–`0006` 补丁（4.19.157 树专用），**不要**与本分支的补丁混用。

## 下载

正式构建版本通过 [GitHub Releases](https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood/releases) 发布；仓库内也提供常用产物的快照。

| 发布格式 | 用途 |
| --- | --- |
| AnyKernel3 ZIP | 在兼容的 Recovery 中刷入；保留设备当前 ramdisk 与 dtb，HyperOS / RisingOS / PixelOS 等 ROM 通用 |
| `Image`（裸内核） | 用 `tools/repack_boot.py` 按目标 ROM 的原厂 boot.img 重打包，供 Fastboot 刷入 |

`prebuilt/BakaSU-picasso-Driftwood-V4.1.0-ak3.zip` 为当前版本的通用 AnyKernel3 包。

`boot.img` 内含各 ROM 自己的 ramdisk，不能跨 ROM 通用，因此 Release 以 AK3 与 `Image` 为主；个别 ROM 专用的 `boot.img`（如 `boot-V4.1.0-hyperos.img`，由对应原厂 boot 重打包）仅作为便利产物提供，换 ROM 后仍需重新打包：

~~~bash
python3 tools/repack_boot.py stock_boot.img Image-V4.1.0 boot.img
~~~

下载前请核对版本、设备型号和 Android 版本。

## 构建指南

### 环境要求

推荐使用 Ubuntu 或 WSL2 Ubuntu。项目测试工具链为 ZyC Clang 23.0.0git 与 LLD 23。

主要依赖：

- Clang 23、LLD 23、LLVM 23
- AArch64 GNU Toolchain
- Python 3、Git、Make、`patch`、`curl`
- 常用内核构建依赖

Ubuntu 安装示例：

~~~bash
sudo apt update
sudo apt install -y \
  build-essential bc bison flex \
  libssl-dev libelf-dev libncurses-dev \
  python3 git patch zip unzip rsync cpio kmod curl \
  binutils-aarch64-linux-gnu gcc-aarch64-linux-gnu
~~~

如果 LLVM 工具安装在带版本号的目录中，请将对应目录加入 `PATH`（或通过 `TC=` 指定），并确认可以找到 `clang`、`ld.lld` 及其他 LLVM 工具。

### 开始构建

~~~bash
git clone https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood.git
cd BakaSU-Redmi-K30-5G-Driftwood
./build.sh
~~~

构建脚本会自动拉取基础内核源码、安装仓库内置的 BakaSU 源码、按顺序应用补丁、写入 `.config` 并编译 `Image`。指定原厂 boot.img 时，还会生成重打包镜像。

### 自定义构建参数

~~~bash
# 复用已经准备好的内核源码树
KSRC=/path/to/kernel ./build.sh

# 指定 Clang 工具链目录
TC=/path/to/clang/bin ./build.sh

# 使用原厂 boot.img 额外生成重打包镜像
BOOT_IMG=stock_boot.img ./build.sh
~~~

### 构建产物

默认产物位于 `out/`：

~~~text
out/
├── Image
└── boot.img   # 仅在指定 BOOT_IMG 时生成
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

> **Ramdisk 提醒：**不同 Android 版本的原厂 ramdisk 通常不通用。仓库提供的 `boot.img` 均为特定 ROM 重打包产物；其他系统版本优先使用 AnyKernel3 包，或使用自己的原厂 boot.img 重打包。

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

**Android 14、15、16 可以使用吗？**  
V4.1.0 已验证 Android 14（HyperOS 2.0）、Android 16（RisingOS、PixelOS）。Android 16 QPR2 及以上依赖 `0009`/`0010` 两个补丁；更旧的版本理论上也可用，但建议按系统版本选择匹配的镜像。

**为什么 `uname -r` 显示的内核版本和系统设置里不一样？**  
这是 V4.1.0 的刻意设计：只有 uid 0 进程（`init`、`netd`、`bpfloader` 等）看到 `5.4.210-Driftwood`，用于满足 Android 16 的 BPF 加载要求；普通应用与系统设置显示真实版本 `4.19.325-Driftwood-V4.1.0`。

**为什么刷入后还需要安装管理器？**  
内核提供 Root 所需的内核接口，管理器负责用户侧的授权与管理功能，两者配合使用。

**可以使用其他 KernelSU 管理器吗？**  
建议优先使用与本项目 BakaSU 驱动版本匹配的管理器，避免接口差异导致功能异常。

**AnyKernel3 ZIP 和 boot.img 应该选哪个？**  
不熟悉 Fastboot 或 ramdisk 匹配时，优先选择适配当前系统的 AnyKernel3 ZIP。只有确认镜像与系统匹配时再直接刷入 boot.img。

## 已知限制

- 工具链：项目记录显示 Clang 23 构建在目标设备上的稳定性较好；更换工具链后建议完整回归。
- Ramdisk：不同 Android 版本的原厂 ramdisk 通常不可互换。
- 内核版本伪装：仅对 uid 0 生效；依赖内核版本的 root 工具可能看到 `5.4.210`，属于预期行为。
- Android 17 / ColorOS 17：当前伪装值为 5.4.210；日志中的 `Android 25Q4 requires kernel 5.10` 目前只是警告，若后续 ROM 将其变为硬性要求，需要调整补丁 `0010` 后重测。
- HyperOS 移植包：`ro.build.fingerprint` 与 `ro.vendor.build.fingerprint` 不一致导致的开机提示属 ROM 侧问题，与本内核无关。
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

- [Akitlove/android_kernel_xiaomi_sm7250](https://github.com/Akitlove/android_kernel_xiaomi_sm7250)
- [HeinUmin/kernel_xiaomi_sm7250](https://github.com/HeinUmin/kernel_xiaomi_sm7250)
- [Baka-SU/BakaSU](https://github.com/Baka-SU/BakaSU)
- [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)
- Driftwood 内核相关贡献者
- Redmi K30 5G 社区、测试者，以及 Claude 和 ChatGPT

内核主体及第三方组件遵循各自源码目录中的许可证。使用、修改或再分发时，请遵守对应上游项目的许可证要求。
