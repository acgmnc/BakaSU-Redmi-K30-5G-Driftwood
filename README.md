# Driftwood V4.1.0 — BakaSU × SuSFS for Redmi K30 5G (picasso)

基于 **Akitlove/android_kernel_xiaomi_sm7250 @ `da42a2f`（Linux 4.19.325-cip133）** 的内核构建分支，
在 V4.0.0 基础上加入 **Android 16 (QPR2 / 25Q2+) 兼容**。

> `main` 分支仍是 4.19.157 (HeinUmin) 基线；本分支的补丁与 `main` **不通用**。

## 版本

| 项 | 值 |
|---|---|
| 内核版本串 | `4.19.325-Driftwood-V4.1.0` |
| 源码基线 | `Akitlove/android_kernel_xiaomi_sm7250` @ `da42a2f` |
| BakaSU | 版本号 35252（`d5e9e025`，源码内置于 `kernel/`） |
| SuSFS | v2.3.0（随基线树集成，由 `0001` 补丁对齐） |
| 工具链 | ZyC clang 23.0.0git + LLD 23 |

## 目录

```
kernel/                 BakaSU 内核驱动源码（构建时安装到树内 KernelSU/kernel）
patches/                构建补丁（0001/0005/0007/0008/0009/0010）
driftwood-v4.1.0.config 完整内核 .config
prebuilt/               预编译产物（AK3）
tools/repack_boot.py    boot.img 重打包工具
build.sh                构建脚本
upstream.lock           锁定的上游版本
```

## 构建

```bash
./build.sh                      # 下载 da42a2f → 装 BakaSU 源码 → 打补丁 → 编译 Image
KSRC=~/work/akitlove-pstore-v230-src ./build.sh   # 复用现成树
BOOT_IMG=stock_boot.img ./build.sh                 # 顺便重打 boot.img
```

输出在 `out/Image`（以及可选的 `out/boot.img`）。

## 补丁说明

| 补丁 | 作用 |
|---|---|
| `0001-driftwood-v4.0.0-base.patch` | 上游 `da42a2f` → 可用树的完整源码差异（SuSFS 2.3.0 集成、KSU `filename` ABI 修复、trace 头路径、缺失头文件 shim） |
| `0005-palm-sensor-bounded-wait.patch` | `palm_sensor_show()` 改 500 ms 超时，避免 I2C `-107` 时 SensorService 挂死触发软重启 |
| `0007-p-sensor-bounded-wait.patch` | 同样的修复补到 `p_sensor_show()` |
| `0008-strip-compiler-urls.patch` | 去掉编译器串里的 `(https://…)`，让 `/proc/version` 通过 MIUI 的单层括号正则 |
| `0009-btf-allow-zero-size-datasec.patch` | 允许零长度 `DATASEC`，修复 Android 16 的 `BPF_BTF_LOAD` EINVAL |
| `0010-per-proc-uname-spoof.patch` | 仅对 uid 0 进程伪装 uname 为 `5.4.210-Driftwood`，通过 netbpfload 的 `25Q2 requires 5.4` 门槛并避免 netd SIGABRT；普通应用仍看到真实 `4.19.325` |

## 预编译产物

`prebuilt/BakaSU-picasso-Driftwood-V4.1.0-ak3.zip` — AnyKernel3 包，Recovery 刷入，
会 dump 当前 boot、只替换内核、保留当前 ROM 的 ramdisk/dtb，适用于 HyperOS / RisingOS / PixelOS 等。

其它 boot 镜像（PixelOS / RisingOS 专用）与校验值见各 Release。

## 已知限制

- 伪装仅对 uid 0 生效：`adb root` 后 `uname -r` 显示 `5.4.210`，`su 2000 -c uname -r` 显示真实 `4.19.325`；
- 日志中 `Android 25Q4 requires kernel 5.10.` 目前只是警告；若 A17/ColorOS 17 变硬门槛，需把 `0010` 的假版本改为 `5.10.x` 重测；
- HyperOS 端口指纹不一致的开机弹窗属 ROM 侧问题。
