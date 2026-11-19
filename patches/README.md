# patches

本分支（`v4.1.0`，基线 4.19.325-cip133 @ `da42a2f`）使用的补丁，按顺序应用：

| 补丁 | 作用 |
|---|---|
| `0001-driftwood-v4.0.0-base.patch` | 上游 → 可用树的完整源码差异：SuSFS v2.3.0 集成、KSU `filename` ABI 修复（`fs/open.c`/`fs/stat.c`）、trace 头 `TRACE_INCLUDE_PATH` 修正、5 个 4.19 缺失头文件 shim |
| `0005-palm-sensor-bounded-wait.patch` | `palm_sensor_show()` 无限等待改 500 ms 超时（防软重启） |
| `0007-p-sensor-bounded-wait.patch` | `p_sensor_show()` 同样的超时保护 |
| `0008-strip-compiler-urls.patch` | `mkcompile_h` 编译串去掉 URL 括号，修复 HyperOS「内核版本 Unavailable」 |
| `0009-btf-allow-zero-size-datasec.patch` | 允许 `size=0` 的 `DATASEC`，修复 Android 16 `BPF_BTF_LOAD` EINVAL |
| `0010-per-proc-uname-spoof.patch` | 仅 uid 0 进程看到 `5.4.210-Driftwood`，通过 netbpfload 25Q2 门槛、避免 netd SIGABRT |

## 与 main 分支的区别

`main` 分支的 `0002`/`0003`/`0004`/`0006` 是针对 4.19.157 (HeinUmin) 树的编译适配与 SuSFS 移植，
**在本分支不适用**：4.19.325 树本身已包含 SuSFS 2.3.0 与所需头文件，差异全部收敛到 `0001`。
`manual-hooks/` 模式也已移除。
