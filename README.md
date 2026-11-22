# Driftwood · SukiSU Nova 版

<p align="center"><strong>SukiSU Nova + KernelPatch(KPM) + SuSFS 2.3.0 for Redmi K30 5G</strong></p>

<p align="center">
  <img src="https://img.shields.io/badge/Device-Redmi%20K30%205G-blue?style=flat-square" alt="Device">
  <img src="https://img.shields.io/badge/Kernel-4.19.325--cip135--st19-green?style=flat-square" alt="Kernel">
  <img src="https://img.shields.io/badge/Root-SukiSU%20Nova-red?style=flat-square" alt="Root">
  <img src="https://img.shields.io/badge/KernelPatch-0.14-8A2BE2?style=flat-square" alt="KernelPatch">
  <img src="https://img.shields.io/badge/KPM-supported-success?style=flat-square" alt="KPM">
  <img src="https://img.shields.io/badge/SuSFS-v2.3.0-orange?style=flat-square" alt="SuSFS">
</p>

> 本分支（`sukisu-nova`）是 [`main`](https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood/tree/main)（**BakaSU 稳定线**）之外的 **SukiSU Nova 实验线**。
> 内核版本串同为 `4.19.325-Driftwood-V4.2.0`，基线同为 Akitlove `susfs-miui`（Linux `4.19.325-cip135-st19`）。

---

## 功能特性

| 功能 | 状态 | 说明 |
| --- | --- | --- |
| SukiSU Nova | ✅ | `builtin` 模式 + `CONFIG_KSU_HACK_ARM64_BRANCH_LINK`，运行时改写调用点，不需要手动 hook 内核源码 |
| **KPM** | ✅ | 实测加载 `hello.kpm` 成功并执行 `init`；依赖 **SukiSU 定制版 KernelPatch 0.14** |
| SuSFS | ✅ | `v2.3.0`，`SUS_PATH`/`SUS_MOUNT`/`SUS_KSTAT`/`SUS_MAP`/`SPOOF_UNAME`/`SPOOF_CMDLINE`/`OPEN_REDIRECT` 等全开 |
| ADB Root | ✅ | `CONFIG_KSU_FEATURE_ADBROOT=y` |
| 编译串修复 | ✅ | 0008 去 URL，系统关于页正常显示内核版本 |
| 版本伪装 | ✅ | `bpfloader`/`netbpfload`/`netd`/`uprobestats` 看到 `5.10.260`，其它进程看真实版本 |

## 已验证（2026-11-23，HyperOS 4 / Android 17）

```
uname -r                        4.19.325-Driftwood-V4.2.0
KP KernelPatch Version: e00     （SukiSU 定制 KP 0.14.0）
KP sukisu_kpm_supercall_install done: 0
KernelSU: extension: registered handler for kpm (id=0, caps=0x0, min_api=0)
[+] KP I load_module_ex: [kpm-hello-demo] succeed
kpm hello init, event: post-fs-data
```

- 开机正常、root 正常、Wi-Fi 正常、KPM 可加载模块。

## 下载

| 文件 | 说明 |
| --- | --- |
| `prebuilt/SukiSU-SKP014-KPM-ak3.zip` | **本分支可直接刷的 AK3**（SukiSU Nova + KP 0.14 + KPM + SuSFS 2.3.0） |
| `prebuilt/BakaSU-picasso-Driftwood-V4.2.0-ak3.zip` | 回退用：BakaSU 稳定版 AK3（不带 KP） |
| `prebuilt/boot-a17-Driftwood-V4.2.0.img` | BakaSU 线 boot（仅对应 ROM 版本可用） |

Release 附件（同文件）：<https://github.com/acgmnc/BakaSU-Redmi-K30-5G-Driftwood/releases/tag/driftwood-v4.2.0-a17>

## 构建

```bash
# 1) 内核：SukiSU Nova + SuSFS 2.3.0（KPM 强制开启）
./scripts/build-sukisu-nova.sh
#   -> out/Image-sukisu-nova

# 2) 注入 KernelPatch + 打 AK3
#    需要 ARM 官方裸机工具链（aarch64-none-elf），否则 .setup.map 超限
TC_ELF=$HOME/toolchains/arm-gnu/bin/aarch64-none-elf- \
  ./scripts/patch-kpimg.sh out/Image-sukisu-nova "DriftwoodKp2026" out/SukiSU-KP-KPM-ak3.zip
```

工具链：

| 用途 | 工具链 |
| --- | --- |
| 内核编译 | ZyC Clang 23.0.0git + LLD 23（`LLVM=1 LLVM_IAS=1`） |
| kpimg 编译 | Arm GNU Toolchain 13.2 `aarch64-none-elf-gcc` |
| kptools | 宿主机 gcc（`make -C tools`） |

> **关键坑**：官方 KernelPatch 无法用于 SukiSU 的 KPM（不认 `SUKISU_KPM_SUPERCALL_MAGIC`），必须用
> [`SukiSU-Nova/SukiSU_KernelPatch_patch`](https://github.com/SukiSU-Nova/SukiSU_KernelPatch_patch)；
> 且 release 里的 `0.11-beta` kpimg 早于 KPM ABI v2，必须用上面的方式从源码重编。详见 [`SUKISU-NOVA.md`](SUKISU-NOVA.md)。

## 刷入

Recovery（OrangeFox）→ Install → `SukiSU-SKP014-KPM-ak3.zip` → 重启。

- AK3 只替换内核，保留当前 ROM 的 ramdisk/dtb；
- 由于 KernelPatch 接管内核启动入口，**刷前请确认手上有可回退的 AK3**；
- 开机后验证：

```bash
adb shell uname -r
adb shell su -c "dmesg | grep -iE 'KernelPatch|kpm' | tail -20"
```

## KPM 模块

管理器从 `/data/adb/kpm/` 加载模块。已测试可用（`/sdcard/kpm/`）：

| 模块 | 说明 |
| --- | --- |
| `hello.kpm` | 最小验证（`kpm hello init`） |
| `inlinehook.kpm` | inline hook 示例 |
| `syscallhook.kpm` | 系统调用 hook 示例 |
| `btf.kpm` | BTF 解析示例 |
| `kconfig.kpm` | 读取内核 config 示例 |
| `hosts_file_redirect_1.1.8.kpm` | hosts 重定向（实用） |
| `selinux_policydb_fix_1.0.6.kpm` | SELinux policydb 修复（实用） |
| `vpnhide.kpm` | 隐藏 VPN 状态（实用，主要为 GKI 设计） |

```bash
adb shell su -c "cp /sdcard/kpm/hello.kpm /data/adb/kpm/"
```

## 已知限制

- `CONFIG_KPM` 在 4.19 上是**强制开启**的（放宽了 `KSU_CAN_USE_KPM` 的 5.10 版本门槛），上游只保证 5.10+；
- SuSFS 仍为 2.3.0：`sus_path` 按 UID 过滤、SELinux `sus_type`/AVD 属于 2.4 特性，本分支以 stub 形式存在；
- KernelPatch 通过镜像注入接管启动入口，4.19 属于“理论支持”范围，稳定性需自行观察；
- superkey 默认 `DriftwoodKp2026`。

## 回退

刷回 `prebuilt/BakaSU-picasso-Driftwood-V4.2.0-ak3.zip`（BakaSU 稳定版，不带 KP）即可。

## 与 main 的关系

| | `main` | `sukisu-nova`（本分支） |
| --- | --- | --- |
| Root | BakaSU 35252 | SukiSU Nova |
| KernelPatch | 无 | 0.14（镜像注入） |
| KPM | 不支持 | **支持** |
| SuSFS | 2.3.0 | 2.3.0 |
| 定位 | 稳定日常 | 实验/尝鲜 |

## 致谢

- [SukiSU-Nova](https://github.com/SukiSU-Nova) — SukiSU + KPM bridge + KernelPatch patch
- [bmax121/KernelPatch](https://github.com/bmax121/KernelPatch)
- [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)
- [Akitlove/android_kernel_xiaomi_sm7250](https://github.com/Akitlove/android_kernel_xiaomi_sm7250)
- [Baka-SU/BakaSU](https://github.com/Baka-SU/BakaSU)（main 线）

## 许可

内核主体与第三方组件遵循各自源码目录中的许可证。
