# SukiSU Nova + KernelPatch(KPM) 版说明

本分支（`sukisu-nova`）是 `main`（BakaSU 版 V4.2.0）之外的 **SukiSU Nova 实验线**，面向 Redmi K30 5G（`picasso`），在 4.19 内核上实现了：

- **SukiSU Nova**（`builtin` 模式，ARM64 branch-link patch，无需手动 hook）
- **SuSFS 2.3.0**（SusFS，带 2.4 API 兼容 shim）
- **KernelPatch 运行时**（`kpimg 0.14.0`，镜像注入方式）
- **KPM**（Kernel Patch Module，实测可加载并执行）

## 验证状态（2026-11-23）

```
uname -r                       4.19.325-Driftwood-V4.2.0
KP KernelPatch Version: e00    （0.14.0）
KP sukisu_kpm_supercall_install done: 0
KernelSU: extension: registered handler for kpm (id=0, caps=0x0, min_api=0)
[+] KP I load_module_ex: [kpm-hello-demo] succeed
kpm hello init, event: post-fs-data
```

- 开机正常、root 正常、Wi-Fi 正常
- KPM 加载 `hello.kpm` 成功，模块 `init` 已执行

## 为什么 KPM 需要 KernelPatch

SukiSU 内核侧（`extension/kpm/kpm.c`）只是**桥**：

```c
fn = find_kernel_symbol_exact("__arm64_sys_truncate");
regs.regs[0] = SUKISU_KPM_SUPERCALL_MAGIC;   // 0x53554b504d000002
regs.regs[8] = SUKISU_KPM_ABI_VERSION;        // 2
if (fn(&regs) != SUKISU_KPM_ABI_VERSION) return -EOPNOTSUPP;
```

真正的 KPM 加载器在 **KernelPatch** 里。注意两点：

1. **不能用官方 KernelPatch**：官方 KP 不认这套 magic，探测会一直失败（管理器显示“KPM 不支持”）。
   必须用 SukiSU 定制仓库：<https://github.com/SukiSU-Nova/SukiSU_KernelPatch_patch>
2. **不能用 release 里的 kpimg**：`0.11-beta`（2025-06）早于 KPM ABI v2（2026-11），里面没有 probe。
   必须用 **ARM 官方裸机工具链**（`aarch64-none-elf-gcc`）从当前源码重编 kpimg；
   用 clang 或 Linux 目标 GCC 会因 `.setup.map` 超出链接脚本限制而失败。

## 构建

```bash
# 1) 编译内核（SukiSU Nova + SuSFS 2.3.0，KPM 已 force-enable）
./scripts/build-sukisu-nova.sh

# 2) 注入 KernelPatch 并打 AK3（需要 aarch64-none-elf 工具链）
TC_ELF=$HOME/toolchains/arm-gnu/bin/aarch64-none-elf- \
  ./scripts/patch-kpimg.sh out/Image-sukisu-nova "DriftwoodKp2026" out/SukiSU-KP-KPM-ak3.zip
```

产物：`out/SukiSU-KP-KPM-ak3.zip`（Recovery 刷入）。

## 刷入

Recovery → Install → `SukiSU-KP-KPM-ak3.zip`（AnyKernel3，只替换内核，保留当前 ROM 的 ramdisk/dtb）。

## KPM 模块

已放到 `/sdcard/kpm/` 的测试模块：

| 模块 | 用途 |
| --- | --- |
| `hello.kpm` | 最小验证（dmesg 打印 `kpm hello init`） |
| `inlinehook.kpm` | inline hook 示例 |
| `syscallhook.kpm` | 系统调用 hook 示例 |
| `btf.kpm` | BTF 解析示例 |
| `kconfig.kpm` | 读取内核 config 示例 |
| `hosts_file_redirect_1.1.8.kpm` | hosts 重定向（实用） |
| `selinux_policydb_fix_1.0.6.kpm` | SELinux policydb 修复（实用） |
| `vpnhide.kpm` | 隐藏 VPN 状态（实用，主要为 GKI 设计） |

管理器从 `/data/adb/kpm/` 加载模块，例如：

```bash
adb shell su -c "cp /sdcard/kpm/hello.kpm /data/adb/kpm/"
```

## 已知限制

- `CONFIG_KPM` 在 4.19 上是**强制打开**的（改了 `KSU_CAN_USE_KPM` 的版本门槛），上游只保证 5.10+；
- SuSFS 仍是 2.3.0，`sus_path` 按 UID 过滤与 SELinux sus_type/AVD 是 2.4 特性，本分支以 stub 形式存在（管理器不会下发）；
- KernelPatch 会接管内核启动入口，刷入前请确认手上有一份能开机的 AK3 可回退；
- superkey 默认为 `DriftwoodKp2026`，需要可自行改。

## 回退

刷回任意可用的 AK3（例如 `prebuilt/BakaSU-picasso-Driftwood-V4.2.0-ak3.zip` 或 `prebuilt/SukiSU-SKP014-KPM-ak3.zip` 去掉 KP 的版本），即可恢复。

## 致谢

- [SukiSU-Nova](https://github.com/SukiSU-Nova)（SukiSU + KPM bridge + KernelPatch patch）
- [bmax121/KernelPatch](https://github.com/bmax121/KernelPatch)
- [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)
- [Akitlove/android_kernel_xiaomi_sm7250](https://github.com/Akitlove/android_kernel_xiaomi_sm7250)
