# BakaSU for Redmi K30 5G (picasso) · Driftwood 4.19

把 **BakaSU**（KernelSU 分支，内核版本 **35252 / v4.2.0-rc3**）移植进
**HeinUmin/kernel_xiaomi_sm7250**（`android-4.19`，4.19.157-Driftwood-v2.2.1）的
Redmi K30 5G（picasso）内核，内置（`built-in`）方式集成。

真机验证环境：MIUI 14 / Android 13（`V14.0.11.0.TLDCNXM`），A-only 单槽，boot 分区 128 MiB。

| 项 | 值 |
|---|---|
| 内核驱动版本 | `v4.2.0-rc3-d5e9e025 (35252/6)` |
| 管理器 | BakaSU / ReSukiSU `v4.2.0-rc3 (35252/6)`，包名 `com.resukisu.resukisu` |
| 内核 | `4.19.157-Driftwood-v2.2.1` |
| SELinux | 强制执行，root 上下文 `u:r:ksu:s0` |
| 工具链 | clang 15.0.7 + LLD 15.0.7（`LLVM=1 LLVM_IAS=1`） |

## 为什么是 BakaSU

之前本项目基于 SukiSU-Ultra。SukiSU 新版上游（`builtin` 分支 5.10+ 架构）改用
`sys_enter` tracepoint + 改写 `sys_call_table` 来挂钩子，在 4.19 上：

- 页表走查认不出段映射（无 `pmd_leaf()`），fixmap 改写 `sys_call_table` 失败；
- 框架在改写失败后仍安装 dispatcher，`init` 的 `execve` 被重定向到空指针，开机即崩。

BakaSU 提供 **`KSU_MANUAL_HOOK`**（官方文档写明支持 3.4+），直接在内核源码里挂钩子，
并且编译期逐个校验钩子是否齐全——这正是 4.19 需要的形态。实测一次启动成功。

## 内核补丁

`patches/` 按顺序应用：

| 补丁 | 作用 |
|---|---|
| `0001-bakasu-manual-hooks.patch` | BakaSU manual hook：`execve`/`post_execveat`、`faccessat`、`stat`（含 `newfstat`/`fstat64` 返回值钩子）、`sys_reboot`；同时移除 Driftwood 自带的老 KernelSU 钩子（`ksu_vfs_read_hook`、`ksu_input_hook` 等，与 BakaSU 的 static_key 实现冲突） |
| `0002-trace-include-paths.patch` | 修正 5 个 trace 头文件的 `TRACE_INCLUDE_PATH`，否则 `make Image` 报 `trace.h not found` |
| `0003-build-fixes.patch` | `techpack/camera` 的 `cam_cci_dev.h` 头文件路径；defconfig 追加 `CONFIG_KSU=y` |
| `0004-headers-shims.patch` | 4.19 缺的 5.x 头文件 shim（`pgtable.h`/`minmax.h`/`unaligned.h`/`hex.h`/`static_call.h`/`uapi/linux/mount.h`） |
| `0005-palm-sensor-bounded-wait.patch` | **软重启修复**：`xiaomi_touch.c` 的 `palm_sensor_show` 把无限等待改成 500 ms 超时，避免 HAL 持锁卡死导致 system_server 被杀 |

BakaSU 侧配置（`build.sh` 自动设置）：

```
CONFIG_KSU=y
CONFIG_KSU_MANUAL_HOOK=y
CONFIG_KSU_MANUAL_HOOK_AUTO_SETUID_HOOK=y     # 4.19 用 LSM 自动 hook setresuid
CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK=y     # 4.19 用 LSM 自动 hook sys_read
CONFIG_KSU_MANUAL_HOOK_AUTO_INPUT_HOOK=y      # 用 input_handler 自动 hook
# CONFIG_KSU_TRACEPOINT_HOOK is not set       # 只支持 GKI 2.0
```

`kernel/Kbuild` 里的版本号按仓库快照钉死（源码没有 git 历史，否则会退化成 30701/v4.1.0）：

```make
KSU_VERSION := 35252
KSU_TAG_NAME := v4.2.0-rc3
KSU_COMMIT_SHA := d5e9e025
KSU_BRANCH_NAME := main
```

对应上游 `Baka-SU/BakaSU@d5e9e025`（main 第 4552 个提交，见 `upstream.lock`）。

## 构建

```bash
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev libncurses-dev \
    python3 git zip unzip rsync cpio kmod \
    binutils-aarch64-linux-gnu gcc-aarch64-linux-gnu clang-15 lld-15 llvm-15

# 让 LLVM=1 找到不带版本后缀的工具（Ubuntu 只装 clang-15 时）
sudo ln -sf /usr/bin/clang-15 /usr/local/bin/clang
sudo ln -sf /usr/bin/ld.lld-15 /usr/local/bin/ld.lld
for t in ar nm objcopy objdump strip readelf ranlib size; do
    sudo ln -sf /usr/bin/llvm-$t-15 /usr/local/bin/llvm-$t
done

./build.sh                        # 拉源码 + 打补丁 + 编译
URL_BOOT=stock_boot.img ./build.sh  # 额外重打包 boot.img
```

产物在 `build/out/`：`Image`、`dtb`、`dtbo.img`，以及可选的 `boot.img`。

## 刷机

- **AnyKernel3**：Release 里的 `BakaSU-picasso-ak3.zip`，recovery 直接刷（保留原 ramdisk）。
- **boot.img**：Release 里的 `boot_bakasu_35252.img`（基于 A13 原厂 ramdisk），
  `fastboot flash boot boot_bakasu_35252.img`。
- 刷前务必备份 boot 分区：`su -c 'dd if=/dev/block/by-name/boot of=/sdcard/boot_backup.img'`。

## 管理器

BakaSU 管理器不在 GitHub Release 发布，本项目使用的是官方 Release 里的
`ReSukiSU_v4.2.0-rc3_35171-arm64-v8a-release.apk`（包名 `com.resukisu.resukisu`，
安装后标题显示 BakaSU，可从 `nightly.link` 更新）。

装好后应显示：`内核驱动版本 v4.2.0-rc3-d5e9e025 (35252/6)`、
`管理器版本 v4.2.0-rc3`，状态「工作中 · Built-in」。

## 说明与已知问题

- **clang 版本**：只有 clang 15 编译的内核在该机型稳定；clang 17 会在 modem 初始化阶段崩溃。
- **A12/A13 ramdisk 不通用**：`boot_bakasu_35252.img` 带的是 A13 原厂 ramdisk，
  A12（`V14.0.5.0.SJDCNXM`）请用 AK3 刷或自行用 A12 的 boot.img 重打包。
- **软重启**：palm 500 ms 超时补丁已包含；长时间验证中（历史版本 4 次开机、约 26 分钟无触发）。
- **BakaSU 管理器版本 ≠ 内核版本**：管理器可从 nightly 更新，内核版本由编译时的
  git 提交数决定，本项目钉死在 35252。

## 历史

- `v4.2.1-r1-41065` / `v4.2.1-r1-41065-palm`：SukiSU-Ultra 41065 版本（旧架构，仍可用）。
- 当前主线切换为 BakaSU 35252。
