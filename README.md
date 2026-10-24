# SukiSU-Ultra 内核 — Redmi K30 5G (picasso) / MIUI 14

为 **Redmi K30 5G（picasso，骁龙 765G / SM7250）** 构建的、可正常开机的
**SukiSU-Ultra root 内核**，运行于 **MIUI 14（Android 12 / Android 13）**。

| 项目 | 值 |
|---|---|
| 内核版本 | `4.19.157-Driftwood-v2.2.1` |
| 内核基线 | [`HeinUmin/kernel_xiaomi_sm7250`](https://github.com/HeinUmin/kernel_xiaomi_sm7250) `android-4.19`（Driftwood 内核源码） |
| Root 方案 | SukiSU-Ultra **v4.2.1-r1**（`builtin` @ `ce75122`，Manual Hook 模式，内核版本号 **41065**） |
| 编译器 | **ZyC clang 15.0.7** + LLD 17.0.6，`LLVM=1 LLVM_IAS=1` |
| 目标系统 | MIUI 14 `V14.0.5.0.SJDCNXM`（Android 12）、MIUI 14 `V14.0.11.0.TLDCNXM`（Android 13） |
| 实测状态 | ✅ 正常开机 ✅ Modem/Radio ✅ SukiSU「工作中」 ✅ 软重启已修复（见下） |

产物使用 **A-only 单槽**布局，boot 分区 128 MiB。

---

## 本仓库实际修掉的两个问题

### 1. 新管理器授权 root 报「更新 app profile 失败」

**现象**：管理器 v4.2.1-r1（41049）给应用授权 root 时提示「更新 app profile 失败」，
换回 v4.2.1（40994）则正常。

**根因**：这棵 4.19 树原先只接了 execve / faccessat / stat 三处 hook，
`kernel/reboot.c` 里的 `sys_reboot` hook 没接，`ksu_handle_sys_reboot()` 虽然编译进
内核却从未被调用 —— ksud 因此拿不到 KernelSU 驱动 fd：

```
E KernelSU: ksud::temporary_root: temporary root manager operation failed:
            could not retrieve kernelsu driver fd
```

41049 把授权 root 改成了 `ksud temporary-root apply` 流程，所以直接失败；
40994 走管理器自身路径，不依赖 ksud 的 fd，所以看起来「没问题」。

**修复**：`patches/0005-sys-reboot-hook.patch` —— 在 `sys_reboot` 入口拦截
`KSU_INSTALL_MAGIC1/2`（`0xDEADBEEF/0xCAFEBABE`）安装驱动 fd 后直接返回，
正常 `reboot(2)` 不受影响。副作用是正的：ksud 的模块安装、KPM、susfs 命令等
依赖驱动 fd 的功能一并恢复。

### 2. MIUI 上的偶发软重启（已定位并修复）

**现象**：开机进入桌面后（约 75~125 秒窗口内）屏幕卡住十几秒 → 回到开机 logo →
再次进入桌面。每轮开机最多一次。

**用户态链条**（此前已查清）：

```
android.hardware.sensors@1.0-service 主线程卡死（D 状态）
  → SensorService::pollHal() 永不返回
  → UiThread 的 SensorService.onUidStateChanged() 等 SensorService 互斥锁
  → system_server Watchdog 60 秒超时 → SIGKILL system_server → 软重启
```

**内核侧根因**（本次抓到，开机 43.95 秒时的现场）：

```
--- hal tid=996  state=D  wchan=kernfs_fop_write      ← HAL 主线程在写
kernfs_fop_write → __vfs_write → vfs_write → __arm64_sys_write

--- hal tid=1059 state=S  wchan=palm_sensor_show      ← 另一个线程在阻塞读
palm_sensor_show → dev_attr_show → sysfs_kf_seq_show
```

1. 传感器 HAL 用**同一个 fd** 访问 `/sys/devices/virtual/touch/touch_dev/palm_sensor`：
   一个线程阻塞读，主线程写；
2. `palm_sensor_show()` 是 `wait_event_interruptible(...)`，**没有超时**；
3. Linux 4.19 的 `kernfs_fop_read()` 在整个 `show()` 期间持有 `of->mutex`；
4. 主线程的写走 `kernfs_fop_write()` → `mutex_lock(&of->mutex)` → **永久 D 状态**；
5. 唯一能唤醒读线程的是触摸驱动 `fts_read_palm_data()` 的 I2C 读取，但触摸总线
   在开机早期会偶发 `i2c_geni 880000.i2c: i2c error :-107`（-ENOTCONN），
   于是读线程永远等不到事件、写线程永远卡住；
6. HAL 主线程卡死 → SensorService 被拖死 → Watchdog 杀掉 system_server → 软重启。

这也解释了为什么是「偶发」：只有触摸 I2C 抽风恰好撞上 HAL 同时读+写 palm 的
窗口，才会从瞬态错误演变成死锁。

**修复**：`patches/0006-palm-sensor-bounded-wait.patch` —— 把无限等待改成
**500 ms 有界等待**，超时就返回当前值：

```c
ret = wait_event_interruptible_timeout(touch_dev->wait_queue,
                                       pdata->palm_changed,
                                       msecs_to_jiffies(500));
```

读线程最多 500 ms 就释放 kernfs 锁，写线程不会再卡死。

**验证**：修复后 MIUI 14（A12）与 MIUI 14（A13）各刷入并多次重启，累计 25 分钟
以上运行未再出现软重启；期间 `i2c error :-107` 仍然每次开机都会出现，
但 `palm_sensor_store` 都能正常返回，传感器 HAL 不再进入 D 状态。

---

## 目录结构

```
patches/                        相对上游 android-4.19 的全部改动
  0001-kernelsu-hooks.patch         fs/exec.c、fs/open.c、fs/stat.c 接入 KernelSU hook
  0002-trace-include-paths.patch    修正 4.19 下 trace 头的 TRACE_INCLUDE_PATH
  0003-build-fixes.patch            cam_cci include 路径 + defconfig 打开 CONFIG_KSU
  0004-headers-shims.patch          补齐 5.x 才有的头文件（pgtable/hex/...）
  0005-sys-reboot-hook.patch        安装 KSU 驱动 fd 的 sys_reboot hook（修 app profile 失败）
  0006-palm-sensor-bounded-wait.patch  palm_sensor 有界等待（修软重启）
  kernelsu-4.19/0001-4.19-compat.patch  给 SukiSU 源码打的 4.19 兼容补丁
kernel/                         SukiSU-Ultra kernel 源码快照（含上述 4.19 兼容补丁）
prebuilt/
  boot.img                      可直接 fastboot 刷入（含全部修复）
  SukiSU-picasso-ak3.zip        AnyKernel3 刷机包（保留目标 ROM 自己的 ramdisk）
tools/repack_boot.py            重打包 boot.img 的小工具
build.sh                        一键构建脚本
upstream.lock                   当前 kernel/ 对应的 SukiSU builtin commit
```

> `kernel/` 相对 SukiSU 上游的改动：`cpu_spoof` 打桩、`kpm.c` 的 `access_ok`
> 改三参数、`KSU_FEATURE_SELINUX_HIDE` 条件编译、sulog 的 `user_arg_ptr` 差异、
> `kernel_includes.h` 补 `fallthrough`/`TWA_RESUME`、Makefile 加 `-std=gnu11`
> 并固定 `KSU_VERSION`。

---

## 使用预编译产物

**方式一：fastboot（只动 boot 分区）**

```bash
fastboot flash boot prebuilt/boot.img
fastboot reboot
```

> `prebuilt/boot.img` 内的 ramdisk 来自 **MIUI 14 / Android 12** 原厂 boot，
> 建议只在 A12 的 MIUI 14 上使用。

**方式二：recovery（OrangeFox / TWRP）**

直接刷 `prebuilt/SukiSU-picasso-ak3.zip`。AnyKernel3 只替换 `Image`/`dtb`/`dtbo`，
**保留当前 ROM 自己的 ramdisk** —— 换 ROM（例如 Android 13 版 MIUI 14）后请用这个。

**激活 root**：安装 SukiSU 管理器 APK（包名 `com.sukisu.ultra`）。
内核侧已就绪，装完会显示「工作中」。首次给应用授权时按提示允许即可。
管理器 40994（v4.2.1）和 41049（v4.2.1-r1）都可以正常授权。

> 刷之前务必备份原厂 boot 分区，恢复时用同样方式刷回。

---

## 从源码构建

```bash
TC=/path/to/clang15/bin ./build.sh
# 或把 clang 放进 PATH 后直接：
./build.sh
```

脚本依次完成：拉取上游源码 → 应用 `patches/*.patch` → 放入 KernelSU 源码 →
生成 defconfig → 编译 `Image` + `dtbo.img` → 收集到 `build/out/`。
设置 `URL_BOOT=/path/to/stock_boot.img` 还会顺带重打包出 `boot.img`。

**环境要求**

- **clang 15**（推荐 [ZyCromerZ/Clang](https://github.com/ZyCromerZ/Clang) `15.0.7`，
  自带 aarch64/arm binutils）+ lld 17
- `build-essential` `bc` `bison` `flex` `libssl-dev` `libelf-dev` `python3` `zip`

该工具链自带的 `ld.lld` 在较新发行版上可能报 `libxml2.so.2` 缺失，改用系统的即可：

```bash
mv $TC/ld.lld $TC/ld.lld.orig
ln -s /usr/bin/ld.lld-17 $TC/ld.lld
```

**构建脚本里处理掉的两个坑**

1. 补丁必须用 `patch -p1` 应用（`patches/` 下的文件是 `a/`、`src/` 前缀；
   用 `-p0` 会掉进 `File to patch:` 交互并静默跳过全部补丁）。
2. defconfig 本身不含 LTO/RELR，但只要 PATH 里有 clang/lld，`syncconfig` 就会把它们
   按默认打开；clang 15 产出的 ThinLTO bitcode 与系统 lld 17 版本不匹配，会直接
   `ld.lld: error: Invalid value reference from metadata`。脚本在 defconfig 后显式
   `scripts/config -d LTO_CLANG -d RELR` 再 `olddefconfig`。

---

## 已知说明

- **vendor 模块无法加载**：内核是 `4.19.157`，而 `/vendor/lib/modules` 下 46 个厂商
  模块按原厂 `4.19.113-perf-ga1b60ef832fb` 编译，vermagic 不匹配，`/proc/modules`
  为空。这是 Driftwood 系列内核的固有特性；WLAN、显示等关键驱动已编入内核本体，
  WiFi、移动网络、显示实测正常。
- **`i2c_geni 880000.i2c: i2c error :-107` 仍会出现**：这是触摸控制器在开机早期的
  偶发不响应，本次只修掉了它引发的 kernfs 死锁；触摸本身工作正常，若遇到防误触
  之类的边角异常，根因在这一层。
- **管理器版本提示**：KernelSU 版本号由 `40000 + 上游 main 提交数 - 2815` 得出，
  当前固定为 **41065**（2026-10-24 构建）。v4.2.1 正式版管理器是 40994、
  manager-ci 是 41064，因此管理器可能提示「需要更新管理器」。这只是版本号提示，
  不影响 root；想消除可把 `kernel/Makefile` 的 `KSU_VERSION` 改成与手上管理器一致
  的数值后重编。
- **内核版本号与 MIUI 原厂不同**（4.19.157 vs 4.19.113），属于基线差异。
- 该内核面向 picasso 的 A11/A12/A13 ROM，不同 MIUI 小版本请自行验证。

---

## 自动同步上游 KernelSU

本仓库不是 SukiSU 的 fork，而是「上游快照 + 本地补丁」：`kernel/` 对应
`upstream.lock` 记录的 `builtin` commit，本地改动集中在 `patches/kernelsu-4.19/`。
`.github/workflows/sync-upstream.yml` 每周一检查上游，有新提交时自动套补丁、
推到 `upstream-sync` 分支并开 PR；补丁冲突则开 issue 报警，不动 `main`。

> CI 只能证明「补丁打得干净」，能否开机必须本地编译 + 真机验证。

---

## 验证记录

**MIUI 14 / Android 12（V14.0.5.0.SJDCNXM）**

```
$ uname -r
4.19.157-Driftwood-v2.2.1
$ getprop sys.boot_completed
1
$ getprop gsm.network.type
LTE
SukiSU 管理器：工作中 / Manual Hook / 内核完整版本 v4.2.1-r1
```

**MIUI 14 / Android 13（V14.0.11.0.TLDCNXM）**

```
$ uname -r
4.19.157-Driftwood-v2.2.1          # #12, ZyC clang 15.0.7 + LLD 17.0.6
$ getprop ro.build.version.release
13
$ su -c id
uid=0(root) context=u:r:ksu:s0
```

- 软重启修复后多次重启（≥4 次开机、累计 25 分钟以上）未复现；
- 期间 `i2c error :-107` 每次开机仍出现，但 `palm_sensor_store` 正常返回、
  `android.hardware.sensors@1.0-service` 不再进入 D 状态；
- 内核侧 `ksud --version` → `ksud 4.2.1-r1 (uapi: 6)`，驱动 fd 正常。

---

## 致谢与许可

- 内核基线：[HeinUmin/kernel_xiaomi_sm7250](https://github.com/HeinUmin/kernel_xiaomi_sm7250)（Driftwood）
- Root 方案：[SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)
- 打包脚本：[EndCredits/AnyKernel3](https://github.com/EndCredits/AnyKernel3) picasso 分支
- 内核源码遵循 **GPL-2.0**
