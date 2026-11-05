# prebuilt

二进制产物不再提交进仓库（体积原因），请从 [Releases](../../releases) 下载：

| 文件 | 说明 |
|---|---|
| `boot_bakasu_35252.img` | 基于 A13 原厂 ramdisk 的 boot 镜像，`fastboot flash boot` 直接刷 |
| `BakaSU-picasso-ak3.zip` | AnyKernel3 刷机包（保留设备原 ramdisk，A12/A13 通用） |
| `Image` | 纯内核镜像，自行重打包用 |
| `ReSukiSU_v4.2.0-rc3_35171-arm64-v8a-release.apk` | BakaSU/ReSukiSU 管理器 |

校验和见仓库根目录 `SHA256SUMS.txt`。

SuSFS 版本（`susfs` 分支 / Release `v4.2.0-rc3-35252-susfs`）：

| 文件 | 说明 |
|---|---|
| `boot_bakasu_susfs.img` | BakaSU 35252 + SuSFS v2.3.0，A13 原厂 ramdisk |
| `BakaSU-picasso-susfs-ak3.zip` | AnyKernel3 包（SuSFS 版） |
| `Image-susfs` | 纯内核镜像（SuSFS 版） |