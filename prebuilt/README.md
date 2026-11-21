# prebuilt

| 文件 | 说明 |
| --- | --- |
| `boot-a17-Driftwood-V4.2.0.img` | Android 17 专用 boot.img；从原厂 boot 重打包，内核 gzip，保留原厂 ramdisk/dtb，cmdline 含 `ramoops_memreserve=4M` |
| `BakaSU-picasso-Driftwood-V4.2.0-ak3.zip` | AnyKernel3 包：Recovery 刷入，dump 当前 boot、只替换内核（包内为 `Image.gz`，保留 gzip 内核格式，不含 dtb/dtbo，避免 vendor_boot 自动布局问题） |

`boot.img` 只适用于对应原厂 boot 的 ROM 版本；其它 ROM 优先用 AK3，或用 `tools/repack_boot.py` 重打包。
