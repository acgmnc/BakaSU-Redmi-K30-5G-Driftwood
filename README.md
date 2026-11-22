# BakaSU × Driftwood

<p align="center"><strong>更纯粹的内核 · A More Pure Kernel</strong></p>

<p align="center">
  <img src="assets/banner.png" alt="BakaSU × Driftwood" width="100%">
</p>

<p align="center">
  <strong>BakaSU + SuSFS for Redmi K30 5G (picasso)</strong><br>
  基于 Akitlove <code>susfs-miui</code>（Linux 4.19.325-cip135-st19），为 Redmi K30 5G 提供定制内核与内核级 Root 支持。<br>
  <em>注：已不再使用 Driftwood 内核源码，但名称保留（改名太麻烦）。</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Device-Redmi%20K30%205G-blue?style=flat-square" alt="Device">
  <img src="https://img.shields.io/badge/4.19.325-Driftwood-V4.2.0-green?style=flat-square" alt="Kernel">
  <img src="https://img.shields.io/badge/Root-BakaSU-red?style=flat-square" alt="Root">
  <img src="https://img.shields.io/badge/SuSFS-v2.3.0-8A2BE2?style=flat-square" alt="SuSFS">
  <img src="https://img.shields.io/badge/Android-11%20~%2017-orange?style=flat-square" alt="Android">
</p>

> **当前版本：** Driftwood `V4.2.0`（`4.19.325-Driftwood-V4.2.0`），基线切换为 Akitlove `susfs-miui`（`4.19.325-cip135-st19`），**支持 Android 17**。

> **旧基线已移除：** 4.19.157（HeinUmin）线与 V4.1.0（cip133-st17）线不再维护，相关分支与补丁已删除。

<details>
<summary>目录</summary>

- [项目简介](#项目简介)
- [项目信息](#项目信息)
- [功能特性](#功能特性)
- [基线选择说明](#基线选择说明)
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

本项目基于 [Akitlove/android_kernel_xiaomi_sm7250](https://github.com/Akitlove/android_kernel_xiaomi_sm7250) 的 `susfs-miui` 分支（Linux **4.19.325-cip135-st19**），面向 Redmi K30 5G（设备代号 `picasso`）适配。

主要工作：

- 将 BakaSU 35252（`v4.2.0-rc3`）集成到该基线；
- 将 SuSFS 从树内自带的 2.2.0 升级为 **2.3.0**（与 BakaSU 的 API 匹配）：替换 `fs/susfs.c`、`include/linux/susfs*.h` 及 6 个 VFS hook 文件，并补 `statfs_by_dentry_wrapper` / `calculate_f_flags_wrapper`；
- 修复系统关于页「内核版本 Unavailable」：`scripts/mkcompile_h` 去掉编译串里的 URL 括号（`patches/0008`）；
- 内核版本串改为 `4.19.325-Driftwood-V4.2.0`；
- 提供 AnyKernel3 刷机包与自动化构建脚本。

**本项目仅面向 Redmi K30 5G。**

## 项目信息

| 项目 | 信息 |
| --- | --- |
| 目标设备 | Redmi K30 5G（`picasso`） |
| SoC | Qualcomm Snapdragon 765G（SM7250） |
| 基础内核 | Akitlove `susfs-miui`，`4.19.325-cip135-st19` |
| 上游仓库 | [Akitlove/android_kernel_xiaomi_sm7250](https://github.com/Akitlove/android_kernel_xiaomi_sm7250) |
| 上游分支 | `susfs-miui`（HEAD `edfcb8d243`） |
| 内核版本串 | `4.19.325-Driftwood-V4.2.0` |
| Root | BakaSU `v4.2.0-rc3-d5e9e025`（version code `35252`） |
| SuSFS | `v2.3.0` |
| 工具链 | ZyC Clang 23.0.0git + LLD 23 |
| 已验证系统 | Android 17、Android 14 |

## 功能特性

### BakaSU

- 版本：`v4.2.0-rc3`，commit `d5e9e025`，version code `35252`；
- 源码内置于仓库 `kernel/`，构建时安装到内核树 `KernelSU/kernel`（`drivers/kernelsu` 是指向它的软链接）。

### SuSFS v2.3.0

启用 9 项功能：

| 配置 | 功能 |
| --- | --- |
| `SUS_PATH` | 隐藏指定路径 |
| `SUS_MOUNT` | 隐藏 su 进程挂载信息 |
| `SUS_KSTAT` | 伪装文件状态 |
| `SUS_MAP` | 隐藏进程 maps |
| `SPOOF_UNAME` | 伪装 uname |
| `SPOOF_CMDLINE_OR_BOOTCONFIG` | 伪装 `/proc/cmdline` |
| `OPEN_REDIRECT` | 重定向打开路径 |
| `ENABLE_LOG` | SuSFS 日志 |
| `HIDE_KSU_SUSFS_SYMBOLS` | 隐藏符号 |

### 版本伪装说明

树内 `newuname()` 已内置 **comm 级伪装**：`bpfloader`、`netbpfload`、`netd`、`uprobestats` 看到 `5.10.260`，其余进程（shell、系统设置、普通应用）看到真实 `4.19.325-Driftwood-V4.2.0`。这是 Android 16/17 的 BPF 加载器与 netd 所需要的，**不是 bug**。

## 基线选择说明（为什么是 cip135-st19）

| 基线 | 版本 | A17 表现 |
| --- | --- | --- |
| **`susfs-miui`（本项目采用）** | `cip135-st19` | ✅ **正常**，且自带 SuSFS 集成（升级到 2.3.0 即可） |
| `ksu-miui-new` | `cip136-st20` | ❌ 约 80–100 秒后在 binder/timer 路径 kernel panic（**纯内核也复现**，与本项目移植无关） |

`cip136-st20` 的 panic 签名（供排查参考）：

```
Unable to handle kernel paging request at virtual address ffffffa800000000
pc : 0xffffffa800000000   lr : call_timer_fn+0xc4
Call trace: expire_timers → run_timer_softirq → __do_softirq → irq_exit
            → binder_dec_node_tmpref → binder_transaction
Kernel panic - not syncing: Fatal exception in interrupt
```

## 下载

| 文件 | 说明 |
| --- | --- |
| `prebuilt/BakaSU-picasso-Driftwood-V4.2.0-ak3.zip` | AnyKernel3 包：Recovery 刷入，只替换内核（`Image.gz`），不含 dtb/dtbo |
| `prebuilt/SukiSU-SKP014-KPM-ak3.zip` | **SukiSU Nova 版** AK3：SukiSU Nova + KernelPatch(KPM) + SuSFS 2.3.0（实验，见 [SukiSU Nova 版](#sukisu-nova-版实验kpm)） |
| `prebuilt/`（Release） | 同版本 AK3 与校验 |

AK3 只替换内核、保留当前 ROM 的 ramdisk/dtb，可跨 ROM 使用。本项目**不再提供成品 boot.img**；如确需自行重打包，可用 `tools/repack_boot.py` 从对应原厂 boot 生成（自用，不在支持范围内）。

## SukiSU Nova 版（实验，KPM）

`main` 是 **BakaSU 35252** 稳定线；另有一个 **SukiSU Nova** 实验分支 `sukisu-nova`：

| 项 | 内容 |
| --- | --- |
| Root | SukiSU Nova（`builtin` + ARM64 branch-link，无需手动 hook） |
| KernelPatch | SukiSU 定制 KP **0.14.0**（`kpimg` 镜像注入） |
| KPM | **可用**（实测加载 `hello.kpm` 成功） |
| SuSFS | 2.3.0（含 2.4 API 兼容 shim） |
| 内核版本串 | `4.19.325-Driftwood-V4.2.0` |

> 注意：KPM 必须用 **SukiSU 定制版 KernelPatch**（`SukiSU-Nova/SukiSU_KernelPatch_patch`），官方 KernelPatch 不认 KPM supercall magic，管理器会显示「不支持」；并且 `kpimg` 必须用 **ARM 裸机工具链**从源码编译（release 的 0.11-beta 太旧，没有 KPM ABI v2）。

构建与刷入细节见分支内 [`SUKISU-NOVA.md`](https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood/blob/sukisu-nova/SUKISU-NOVA.md)，AK3 见上方下载表。

## 构建指南

### 环境要求

Ubuntu / WSL2 Ubuntu，ZyC Clang 23 + LLD 23（`TC=` 可指定），`curl`、`python3`、`patch`、`bc`、`bison`、`flex`、`aarch64-linux-gnu-gcc`。

### 开始构建

```bash
./build.sh                      # 下载 susfs-miui → 装 BakaSU → 解压 SuSFS 2.3.0 → 补丁 → 编译
KSRC=/path/to/tree ./build.sh   # 复用现成树
BOOT_IMG=stock_boot.img ./build.sh   # 顺便重打包 boot
```

构建脚本做的事：

1. 下载 `Akitlove/android_kernel_xiaomi_sm7250` 的 `susfs-miui` 分支 tarball；
2. 把仓库 `kernel/` 安装为内核树的 `KernelSU/kernel`，并修正 `drivers/kernelsu` 软链接；
3. 解压 `susfs-2.3.0-files.tar.gz`（SuSFS 2.3.0 的 3 个核心文件 + 6 个 VFS hook 文件）覆盖到树；
4. 打 `patches/0008-strip-compiler-urls.patch`；
5. 给 `fs/statfs.c` 补 `statfs_by_dentry_wrapper` / `calculate_f_flags_wrapper`；
6. 给 4 个目录的 Makefile 补 `ccflags-y += -I$(src)`（trace/camera 头路径）；
7. 写入 `driftwood-v4.2.0.config`、`olddefconfig`、编译 `Image`。

产物在 `out/Image`（可选 `out/boot.img`）。

### 打包镜像

```bash
# AK3（Recovery 刷机包；内部会 gzip 成 Image.gz，不含 dtb/dtbo）
./scripts/pack-ak3.sh out/Image out/BakaSU-picasso-Driftwood-V4.2.0-ak3.zip

# boot.img（从原厂 boot 重打包；内核 gzip，保留 ramdisk/dtb，cmdline 追加 ramoops_memreserve=4M）
python3 scripts/pack-boot.py stock_boot.img out/Image out/boot.img
```

## 刷入说明

### 刷入（AK3）

Recovery（OrangeFox）→ Install → 选择对应 AK3 → 重启。

| 版本 | AK3 |
| --- | --- |
| BakaSU 稳定版 | `prebuilt/BakaSU-picasso-Driftwood-V4.2.0-ak3.zip` |
| SukiSU Nova 版 | `prebuilt/SukiSU-SKP014-KPM-ak3.zip` |

> AK3 会 dump 当前 boot、只替换内核，保留原 ROM 的 ramdisk/dtb 与 cmdline，因此跨 ROM 更安全。

## 管理器

BakaSU / ReSukiSU 管理器，包名 `com.resukisu.resukisu`，`arm64-v8a`，版本 `v4.2.0-rc3`。管理器 APK 不由本仓库构建。

## 常见问题

**为什么关于手机显示 4.19.325，而某些进程看到 5.10.260？**  
按设计：只有 `bpfloader`/`netbpfload`/`netd`/`uprobestats` 被伪装，其它进程看真实版本。

**支持哪些 Android 版本？**  
Android 17 已实机验证；Android 14 同样可用；其它版本请自测并备份原厂 boot。

**为什么只提供 AK3、不提供 boot.img？**
boot.img 绑定特定 ROM 的 ramdisk/dtb，刷错分区或跨 ROM 使用容易无法开机；AK3 只替换内核、保留当前 ROM 的 ramdisk/dtb，更安全也更通用，因此本项目只发布 AK3。

## 已知限制

- 模块 vermagic：A17 的 `/vendor/lib/modules` 按 `cip134-st18` 编译，与本内核（`cip135-st19`）不完全匹配，个别 DLKM（如音频）可能加载失败；Wi‑Fi 已实测正常；
- 版本伪装按 comm，若某些新组件需要 uid0 级伪装需另行添加；
- `cip136-st20` 基线在 A17 上存在 binder/timer panic，本项目**不使用**该基线；
- 本内核为 A17 专用产物，跨 ROM 使用需重打包并自测。

## 免责声明

- 本项目仅供学习、研究与技术交流使用；
- 解锁 Bootloader、刷入第三方内核存在风险；
- 刷入不匹配镜像可能导致无法启动或数据丢失；
- 作者不对使用本项目造成的后果承担责任。

## 致谢与许可证

- [Akitlove/android_kernel_xiaomi_sm7250](https://github.com/Akitlove/android_kernel_xiaomi_sm7250)
- [HeinUmin/kernel_xiaomi_sm7250](https://github.com/HeinUmin/kernel_xiaomi_sm7250)（历史基线）
- [Baka-SU/BakaSU](https://github.com/Baka-SU/BakaSU)
- [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)
- 社区测试者

内核主体及第三方组件遵循各自源码目录中的许可证。
