#!/usr/bin/env bash
#
# 构建 SukiSU-Ultra + Driftwood 内核 for Redmi K30 5G (picasso)
#
# 用法:
#   ./build.sh                     # 全自动：拉源码 -> 打补丁 -> 编译 -> 打包
#   KSRC=/path/to/kernel ./build.sh  # 复用已有源码树
#
# 环境要求:
#   - clang 15 (推荐 ZyCromerZ/Clang 15.0.7)，需在 PATH 中，
#     或通过 TC=/path/to/clang15/bin 指定
#   - python3, zip, bc, bison, flex, libssl-dev, libelf-dev
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-$HERE/build}"
KSRC="${KSRC:-$WORK/kernel-src}"
UPSTREAM="${UPSTREAM:-https://github.com/HeinUmin/kernel_xiaomi_sm7250.git}"
BRANCH="${BRANCH:-android-4.19}"
JOBS="${JOBS:-$(nproc)}"

TC="${TC:-}"                                # clang15 bin 目录（可选）
URL_BOOT="${URL_BOOT:-}"                    # 原厂 boot.img 路径（可选）
DEFCONFIG="vendor/picasso_user_defconfig"
TARGET_GCC="aarch64-linux-gnu-"

msg() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- 源码
if [ -d "$KSRC/.git" ]; then
    msg "复用已有源码树: $KSRC"
else
    msg "拉取上游源码 ($UPSTREAM @ $BRANCH)"
    mkdir -p "$WORK"
    git clone --depth=1 -b "$BRANCH" "$UPSTREAM" "$KSRC"
fi
cd "$KSRC"

# ---------------------------------------------------------------- 补丁
msg "应用补丁"
for p in "$HERE"/patches/*.patch; do
    echo "  - $(basename "$p")"
    patch -p1 --forward --batch --silent < "$p" || {
        # 已经被应用过则跳过
        patch -p1 --forward --batch --dry-run --silent < "$p" >/dev/null 2>&1 \
            && die "补丁失败: $p" || echo "    (已应用，跳过)"
    }
done

# ---------------------------------------------------------------- KernelSU
msg "安装 KernelSU 源码"
rm -rf KernelSU
mkdir -p KernelSU
cp -a "$HERE/kernel" KernelSU/kernel
rm -rf drivers/kernelsu
ln -sfn ../KernelSU/kernel drivers/kernelsu
grep -q 'kernelsu' drivers/Makefile || echo 'obj-$(CONFIG_KSU) += kernelsu/' >> drivers/Makefile
grep -q 'drivers/kernelsu/Kconfig' drivers/Kconfig || \
    sed -i 's|^endmenu$|source "drivers/kernelsu/Kconfig"\nendmenu|' drivers/Kconfig

# ---------------------------------------------------------------- 工具链
if [ -n "$TC" ]; then
    export PATH="$TC:$PATH"
fi
command -v clang >/dev/null || die "找不到 clang，请设置 TC=/path/to/clang15/bin 或把 clang 加入 PATH"
case "$(clang --version | head -1)" in
    *"version 15."*) : ;;
    *) echo "警告: 实测只有 clang 15 编译的内核能在本机型稳定启动（clang 17 会在 modem 初始化时崩溃）" ;;
esac

export ARCH=arm64
export CC=clang
export LD=ld.lld
export AR=llvm-ar
export NM=llvm-nm
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export STRIP=llvm-strip
export CROSS_COMPILE="$TARGET_GCC"
export CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
export CLANG_TRIPLE=aarch64-linux-gnu-

MAKEFLAGS_COMMON=(-j"$JOBS" LLVM=1 LLVM_IAS=1)

# ---------------------------------------------------------------- 编译
msg "生成 defconfig"
make "${MAKEFLAGS_COMMON[@]}" "$DEFCONFIG"

# defconfig 里没有 LTO / RELR；只要 PATH 里有 clang+lld，syncconfig 就会按默认值把它们
# 打开。clang 15 产出的 ThinLTO bitcode 与系统 lld 17 版本不匹配，链接时会直接报
# "Invalid value reference from metadata"，所以这里显式关掉，和已验证的产物保持一致。
./scripts/config --file .config -d LTO_CLANG -d RELR
make "${MAKEFLAGS_COMMON[@]}" olddefconfig

msg "编译内核（Image + dtbo.img）"
make "${MAKEFLAGS_COMMON[@]}" Image dtbo.img

# ---------------------------------------------------------------- 打包
msg "生成 dtb"
find arch/arm64/boot/dts/vendor/qcom -name '*.dtb' -exec cat {} + > arch/arm64/boot/dtb

OUT="$WORK/out"
rm -rf "$OUT"; mkdir -p "$OUT"
cp -f arch/arm64/boot/Image "$OUT/Image"
cp -f arch/arm64/boot/dtbo.img "$OUT/dtbo.img"
cp -f arch/arm64/boot/dtb "$OUT/dtb"

if [ -n "$URL_BOOT" ] && [ -f "$URL_BOOT" ]; then
    msg "重打包 boot.img"
    python3 "$HERE/tools/repack_boot.py" \
        "$URL_BOOT" "$OUT/Image" "$OUT/boot.img" "$OUT/dtb"
fi

msg "完成"
echo "产物目录: $OUT"
ls -lh "$OUT"
cat <<'TIP'

提示:
  fastboot flash boot <OUT>/boot.img      # 只刷 boot 分区
  或用 AnyKernel3（EndCredits/AnyKernel3 的 picasso 分支）把
  Image + dtb + dtbo.img 打成一个 recovery 刷机包

  激活 root 需安装 SukiSU 管理器 APK (com.sukisu.ultra) v4.2.1
TIP
