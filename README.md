# SukiSU-Ultra 内核 — Redmi K30 5G (picasso) / MIUI 14

为 **Redmi K30 5G（picasso，骁龙 765G / SM7250）** 构建的、可正常开机的
**SukiSU-Ultra root 内核**，运行于 **MIUI 14.0.5（Android 12）**。

| 项目 | 值 |
|---|---|
| 内核版本 | `4.19.157-Driftwood-v2.2.1` |
| 内核基线 | [`HeinUmin/kernel_xiaomi_sm7250`](https://github.com/HeinUmin/kernel_xiaomi_sm7250) `android-4.19` 分支（即 Driftwood 内核源码） |
| Root 方案 | SukiSU-Ultra **v4.2.1**（`builtin` 分支，Manual Hook 模式） |
| 编译器 | **ZyC clang 15.0.7** + lld 17.0.6，`LLVM=1 LLVM_IAS=1` |
| 目标系统 | MIUI 14.0.5.0.SJDCNXM / Android 12（也适用于其他 picasso 的 A11/A12 ROM） |
| 实测状态 | ✅ 正常开机、✅ Modem/Radio 工作（LTE/中国移动）、✅ KernelSU 显示「工作中」、✅ 连续运行 9 分钟以上无重启 |

产物使用 **A-only 单槽**布局，boot 分区 128 MiB。

---

## 为什么是 clang 15 而不是更新的版本

这是本仓库最关键的结论：

> **用 clang 17 编译出来的内核能启动到开机动画，但会在 modem/radio 初始化时崩溃重启。**

现象非常有迷惑性：表现为「间歇性启动失败」，偶尔能进系统、有时直接卡第一屏重启。真正的规律是——
**只要 radio 被拉起就崩**，所以安全模式 / 飞行模式（不启动 radio）能进桌面，一关飞行模式立刻死机。

换成与原始 Driftwood 同代的 **clang 15.0.7** 后一次性通过。

排查中已排除的假设（都做过对照验证，不是猜测）：

| 假设 | 结论 |
|---|---|
| vermagic / 厂商模块版本不匹配 | ❌ 原版 Driftwood 同样不匹配也能开机 |
| `CONFIG_STATIC_USERMODEHELPER_PATH` 为空 | ❌ 这棵树本来如此 |
| SukiSU 的 execve/faccessat/stat hook 干扰 | ❌ 停用三处 hook 后仍然崩 |
| KernelSU 代码本身 | ❌ 同上 |
| 设备树 / dtbo 不匹配 | ❌ 同一套 dtb+dtbo |

---

## 目录结构

```
patches/                     相对上游 android-4.19 分支的全部改动
  0001-kernelsu-hooks.patch      在 fs/exec.c、fs/open.c、fs/stat.c 接入 KernelSU hook
  0002-trace-include-paths.patch 修正 4.19 下 trace 头的 TRACE_INCLUDE_PATH
  0003-build-fixes.patch         cam_cci include 路径 + defconfig 打开 CONFIG_KSU
  0004-headers-shims.patch       为 KernelSU 补齐 5.x 才有的头文件（pgtable/hex/...）
kernel/                      SukiSU-Ultra kernel 源码（含 4.19 兼容补丁，173 个文件）
prebuilt/
  boot.img                   可直接 fastboot 刷入（已实测可开机）
  SukiSU-picasso-ak3.zip     AnyKernel3 刷机包（含 Image + dtb + dtbo）
```

> `kernel/` 里相对 SukiSU 上游的补丁：`cpu_spoof`（依赖 5.x vDSO 布局）打桩、
> `kpm.c` 的 `access_ok` 改三参数、`KSU_FEATURE_SELINUX_HIDE` 与
> `ksu_selinux_hide_*` 条件编译保护、sulog 的 `user_arg_ptr` 传值差异、
> `kernel_includes.h` 补 `fallthrough`/`TWA_RESUME`、Makefile 加 `-std=gnu11`。

---

## 使用预编译产物

**方式一：fastboot（推荐，只动 boot 分区）**

```bash
fastboot flash boot prebuilt/boot.img
fastboot reboot
```

**方式二：recovery（OrangeFox/TWRP）**

直接刷 `prebuilt/SukiSU-picasso-ak3.zip`。

> 刷之前务必备份原厂 boot 分区。恢复时把备份的 boot.img 用同样方式刷回即可。

**激活 root**：安装 SukiSU 管理器 APK（包名 `com.sukisu.ultra`）。
内核侧已就绪，装完管理器会显示「工作中」。
之后再打开任何需要 root 的应用，管理器会弹出授权框，允许后即可使用。

---

## 从源码构建

```bash
./build.sh
```

脚本会依次完成：拉取上游源码 → 应用补丁 → 放入 KernelSU 源码 →
配置工具链 → 编译 `Image` + `dtbo.img` → 重打包 `boot.img`。

### 工具链准备

需要 **clang 15**（推荐 [ZyCromerZ/Clang](https://github.com/ZyCromerZ/Clang) 的
`15.0.7` 版本，自带 aarch64 / arm 的 GNU binutils）。

注意该工具链自带的 `ld.lld` 可能依赖老的 `libxml2.so.2`，在新发行版上会报
`cannot open shared object file`；解决办法是改用系统自带的 `ld.lld`：

```bash
mv $TC/bin/ld.lld $TC/bin/ld.lld.orig
ln -s /usr/bin/ld.lld-17 $TC/bin/ld.lld
```

### 依赖

```
build-essential bc bison flex libssl-dev libelf-dev python3 zip unzip
aarch64-linux-gnu binutils（工具链通常自带）
```

---

## 已知说明

- **管理器提示「需要更新管理器」**：内核里的 KernelSU 版本号（41047）比
  v4.2.1 正式版管理器（40994）新一点，因为本内核从 `builtin` 分支最新提交编译。
  这是版本号提示，**不影响 root 使用**。若想消除提示，可把
  `kernel/Makefile` 里的 `KSU_VERSION` 固定为 `40994` 后重编内核。
- **内核版本号与 MIUI 原厂不同**（`4.19.157` vs 原厂 `4.19.113`），因此
  `/vendor/lib/modules` 会因 vermagic 不匹配而无法加载。这是 Driftwood 系列
  内核的固有特性；该内核把 WLAN、显示等关键驱动都编进了内核本体，实测
  WiFi、移动网络、显示均正常。
- 该内核面向 picasso 的 A11/A12 ROM；不同 MIUI 小版本请自行验证。

---

## 验证记录

在 MIUI 14.0.5.0.SJDCNXM / Android 12 实机验证：

```
$ uname -r
4.19.157-Driftwood-v2.2.1

$ getprop sys.boot_completed
1

$ getprop gsm.network.type
LTE
$ getprop gsm.operator.alpha
中国移动

SukiSU 管理器：工作中 / Manual Hook / 内核完整版本 v4.2.1-SukiSU-Ultra
/proc/uptime 连续 549 秒无重启
```

---

## 致谢与许可

- 内核基线：[HeinUmin/kernel_xiaomi_sm7250](https://github.com/HeinUmin/kernel_xiaomi_sm7250)（Driftwood）
- Root 方案：[SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)
- 打包脚本：[EndCredits/AnyKernel3](https://github.com/EndCredits/AnyKernel3) picasso 分支
- 内核源码遵循 **GPL-2.0**
