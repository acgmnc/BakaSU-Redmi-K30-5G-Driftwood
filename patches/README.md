# patches

默认（**SuSFS 模式**，`build.sh` 使用）：

| 补丁 | 作用 |
|---|---|
| `0002-trace-include-paths.patch` | 修正 5 个 trace 头文件的 `TRACE_INCLUDE_PATH` |
| `0003-build-fixes.patch` | `cam_cci` 头文件路径；defconfig 追加 `CONFIG_KSU=y` |
| `0004-headers-shims.patch` | 4.19 缺的 5.x 头文件 shim |
| `0005-palm-sensor-bounded-wait.patch` | **软重启修复**：palm 传感器等待改 500 ms 超时 |
| `0006-susfs-v2.3.0-4.19.patch` | SuSFS v2.3.0 移植 + BakaSU `KSU_SUSFS` 所需的全部内核钩子 |

## manual-hooks/ 是另一套模式，默认不参与构建

`manual-hooks/0001-bakasu-manual-hooks.patch` 是旧的 `KSU_MANUAL_HOOK` 模式补丁，
它和 `0006` 修改**同一批文件**（`fs/exec.c`、`fs/read_write.c`、`fs/open.c`、
`fs/stat.c`、`kernel/reboot.c`、`drivers/input/input.c`），钩子实现互斥，
**不能和 0006 同时应用**。

想编非 SuSFS 版：

1. 用 `patches/manual-hooks/0001-bakasu-manual-hooks.patch` 替代 `0006`
2. `build.sh` 配置改为 `-e KSU_MANUAL_HOOK -d KSU_SUSFS`

## 历史坑（已修）

`build.sh` 曾经把 `0001` 和 `0006` 一起按顺序应用。`0006` 是针对「未打 0001」的树生成的，
于是 `fs/exec.c`、`fs/read_write.c`、`drivers/input/input.c` 三个文件的 hunk 冲突，
而旧的错误处理把失败当成「已应用」静默跳过，导致：

- `ksu_handle_post_execveat_sucompat`、`ksu_setup_preinit_file` 等钩子缺失
- 编译仍能通过（BakaSU 的检查只看符号名），但 su 会话/preinit 行为不完整

现在 `build.sh` 会：

- 用反向 `dry-run` 判断「已应用」，否则**直接失败退出**
- 打补丁后逐个校验关键钩子是否存在
- `olddefconfig` 后校验 `CONFIG_KSU_SUSFS=y`、`KSU_MANUAL_HOOK`/`KSU_TRACEPOINT_HOOK` 互斥等
- 所有 `make` 调用都带 `< /dev/null`，避免 kconfig 无 tty 时交互死循环
