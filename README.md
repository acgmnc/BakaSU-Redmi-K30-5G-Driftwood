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

### 已知问题：MIUI 上的偶发软重启

**现象**：开机进入桌面几分钟后，屏幕卡住十几秒 → 回到开机 logo → 再次进入桌面。
每轮开机后最多出现一次，之后不再复现；但手动重启后会再次出现。

**触发条件**：MIUI 13 及以上几乎必然触发；**Android 12 / MIUI 14 上属于偶发**。
同一内核在类原生 ROM 上不出现。

#### 已确认的机制：system_server 被 Watchdog 杀掉

> **这不是内核崩溃，是 Android 用户空间的自杀式重启。**

实测抓到的完整链路（两次独立复现，证据一致）：

```
02:08:55.171  1806  2087 I watchdog: Blocked in handler on ui thread (android.ui)
02:08:55...   watchdog 尝试用 debuggerd 转储所有进程堆栈
02:09:0x      libdebuggerd_client: failed to send signal to pid 588: Permission denied
02:09:0x      watchdog: avc: denied { signal } for comm="watchdog"
                scontext=u:r:system_server:s0 tcontext=u:r:vendor_hal_keymaster_qti:s0
02:09:04.637  1806  2087 I Process : Sending signal. PID: 1806 SIG: 9   ← 杀掉 system_server
02:09:04.8xx  Sensors / AudioFlinger / Gnss / Camera / SurfaceFlinger: service died ...
              ↓
        zygote 重启 → system_server 换新 PID → SystemUI 重启 → 回到桌面
```

即：**system_server 的 `android.ui` 线程被阻塞 → Watchdog 超时 → 抓不到堆栈 → 直接 SIGKILL 整个
system_server → Android 用户空间整体重启。**

#### 如何区分"软重启"和真重启

两种情况的屏幕表现几乎一样，但判据完全不同：

| 判据 | 含义 |
|---|---|
| `/proc/uptime` **归零** | 内核重启（真重启） |
| `uptime` 连续，但 `pidof zygote64 system_server` **PID 变化** | 用户空间重启（本问题） |
| 两者都没变 | 只是 UI 卡顿/掉帧 |

本问题属于第二种。另可用 `pidof` 对比 `ps -A -o PID,STIME,NAME` 里的启动时间快速确认。

#### 故障窗口内观察到的异常

| 观察 | 说明 |
|---|---|
| `android.hardware.sensors@1.0-service` 主线程 **持续 50 秒处于 `D` 状态** | 卡在内核不可中断调用里，重启后自行恢复 |
| `[crtc_commit:109]` 长期 `D` 状态 | DRM 显示提交线程阻塞，与"屏幕卡住"现象吻合 |
| load average 由 1.3 飙升至 12.5 | 系统严重饱和（8 核） |
| `/proc/*/wchan`、`/proc/*/stack` | 无 root 不可读，无法直接定位内核等待点 |

#### 为什么拿不到 ANR 堆栈

Watchdog 本该把各进程堆栈写入 `/data/anr/`，但被 SELinux 拒绝（见上面的 `avc: denied { signal }`），
所以最关键的证据缺失。要定位"到底是谁阻塞了 UI 线程"，需要 root 后读取 `/data/anr/`。

#### 已排除的因素

| 怀疑点 | 结论 |
|---|---|
| 内核 panic / 硬件看门狗 | 无 panic 记录，`console-ramoops` 里没有 Oops |
| `init` / `vendor_init` SIGABRT | 原厂内核日志里同样存在，是 MIUI 正常行为 |
| 传感器 HAL 彻底损坏 | 重启后 `sensorservice` 正常注册，36 个传感器可用 |
| 内存压力 / lmkd | 可用内存 2.6 GB，无击杀记录 |
| 音频模块缺失 | 音频功能实测正常（驱动已编入内核本体） |
| SukiSU hook 干扰 | 停用三处 hook 后现象不变 |

#### 背景因素（推测，未证实）

本内核版本为 `4.19.157`，而 `/vendor/lib/modules` 下 46 个厂商模块按原厂
`4.19.113-perf-ga1b60ef832fb` 编译，vermagic 不匹配导致**一个模块都加载不了**
（`/proc/modules` 为空）。MIUI 的 `ANDR-PERF-RESOURCEQS`、`ACDB-LOADER` 等 HAL 因此持续报错。
类原生 ROM 不依赖这些模块，这或许能解释"为什么类原生不出现"。

#### 自行排查的建议方法

1. **抓 logcat，但注意 tag 是小写 `watchdog`**（搜大写 `WATCHDOG` 会漏掉）
2. 崩溃后立刻读内核侧记录（**无需 root**）：
   ```bash
   adb shell cat /sys/fs/pstore/console-ramoops-0
   ```
   末尾若是 `reboot: Restarting system with command 'userrequested'`，说明是 orderly 重启而非 panic
3. 同时轮询 `ps -A -T -o PID,TID,STAT,NAME`，观察哪些线程掉进 `D` 状态
4. 注意 `adb logcat` 的输出**只在进程退出时才刷盘**——设备重启导致 adb 断线时才会写入文件，
   采样文件显示 0 字节是正常的，不要误以为没在录

---

## 自动同步上游 KernelSU

本仓库**不是** SukiSU 的 fork，而是把 KernelSU 实现以「上游快照 + 本地补丁」的形式放在
`kernel/` 下。因此上游更新走 **分支 + PR** 流程，绝不直接改 `main`。

| 文件 | 作用 |
|---|---|
| `upstream.lock` | 记录当前 `kernel/` 对应的 SukiSU `builtin` 分支 commit |
| `patches/kernelsu-4.19/` | 我们对 KernelSU 的全部本地改动（1 个补丁 / 7 个文件） |
| `.github/workflows/sync-upstream.yml` | 每周一自动检查并开 PR |
| `.github/pr-template-sync.md` | PR 正文模板 |

### 流程

```
每周一 04:00 UTC（或手动 workflow_dispatch）
        │
        ├─ 上游 builtin HEAD == upstream.lock ? ── 是 ──> 结束
        │
        否
        │
        ├─ 拉上游 kernel/ 快照
        ├─ 逐个应用 patches/kernelsu-4.19/*.patch（先 --dry-run 预检）
        │
        ├─ 有冲突 ──> 开 issue 报警，不提交任何东西，main 不受影响
        │
        └─ 无冲突 ──> 推到 upstream-sync 分支 ──> 开/更新 PR
```

手动触发：**Actions → Sync SukiSU-Ultra upstream → Run workflow**。

### 合并前必须人工完成

> **CI 只能证明「补丁打得干净」，无法证明「内核能开机」。**

1. 看 workflow 日志，确认补丁全部干净应用
2. 本地 `./build.sh` 编译（**必须 clang 15**）
3. **真机刷入并确认能开机** —— 这一步不能省
4. 注意 `KSU_VERSION` 随上游 commit 数变化，管理器可能再次提示「需要更新管理器」

### 为什么不做「全自动合并」

- 上游 `builtin` 只是**目前**支持 4.19，随时可能按 5.x 重构
- 内核「能编译」≠「能开机」：本项目就踩过 clang 17 零错误编译、刷入后 modem 崩溃的坑
- 自动化替代不了真机验证，所以合并权必须留在人手上

### 上游改动导致补丁冲突时怎么修

```bash
git clone --depth 1 -b builtin https://github.com/SukiSU-Ultra/SukiSU-Ultra.git /tmp/up
cp -a /tmp/up/kernel /tmp/staged-kernel && cd /tmp/staged-kernel
patch -p1 --forward < /path/to/repo/patches/kernelsu-4.19/0001-4.19-compat.patch
# 看 reject 文件，按 4.19 实际 API 修正后重新生成补丁：
diff -u /tmp/up/kernel/<file> /tmp/staged-kernel/<file> \
     --label a/kernel/<file> --label b/kernel/<file>
```

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
