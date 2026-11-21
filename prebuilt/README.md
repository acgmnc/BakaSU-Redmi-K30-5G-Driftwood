# prebuilt

| 文件 | 说明 |
| --- | --- |
| `boot-a17-Driftwood-V4.2.0.img` | Android 17（HyperOS 4 / OS4.0.0.16）专用 boot.img；从原厂 boot 重打包，内核 gzip，保留原厂 ramdisk/dtb，cmdline 含 `ramoops_memreserve=4M` |

该镜像只适用于对应原厂 boot 的 ROM 版本；其它 ROM 请用 `tools/repack_boot.py` 重打包。
