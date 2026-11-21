# patches

| 补丁 | 作用 |
| --- | --- |
| `0008-strip-compiler-urls.patch` | 去掉 `scripts/mkcompile_h` 编译串里的 `(https://...)` 括号，修复 HyperOS「内核版本 Unavailable」 |

SuSFS 2.3.0 的文件（`fs/susfs.c`、`include/linux/susfs*.h`、6 个 VFS hook 文件）以 `susfs-2.3.0-files.tar.gz` 形式提供，由 `build.sh` 解压覆盖；`fs/statfs.c` 的两个 wrapper 由 `build.sh` 自动补。
