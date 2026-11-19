# prebuilt

| 文件 | 说明 |
|---|---|
| `BakaSU-picasso-Driftwood-V4.1.0-ak3.zip` | AnyKernel3 包，Recovery 刷入；dump 当前 boot、只换内核、保留当前 ROM 的 ramdisk/dtb，适用于 HyperOS / RisingOS / PixelOS 等 |

校验值见仓库根目录 `SHA256SUMS.txt`。

其它镜像（PixelOS / RisingOS 专用 boot.img、裸 Image）随 Release 提供；
需要给别的 ROM 用时，可以用 `tools/repack_boot.py <该ROM的boot.img> <Image> out.img` 自行重打包。
