#!/usr/bin/env bash
#
# 构建 BakaSU + SuSFS + Driftwood 内核 for Redmi K30 5G (picasso)
#
# 用法:
#   ./build.sh                       # 全自动：拉源码 -> 打补丁 -> 编译 -> 打包
#   KSRC=/path/to/kernel ./build.sh  # 复用已有源码树（需为干净的 android-4.19）
#   URL_BOOT=stock_boot.img ./build.sh  # 额外重打包 boot.img
#
# 环境要求:
#   - clang 15（实测 ZyC clang 15.0.7 / Ubuntu clang-15 均可），需在 PATH 中，
#     或通过 TC=/path/to/clang/bin 指定
#   - python3, zip, bc, bison, flex, libssl-dev, libelf-dev
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-$HERE/build}"
KSRC="${KSRC:-$WORK/kernel-src}"
UPSTREAM="${UPSTREAM:-https://github.com/HeinUmin/kernel_xiaomi_sm7250.git}"
BRANCH="${BRANCH:-android-4.19}"
JOBS="${JOBS:-$(nproc)}"

TC="${TC:-}"                                # clang bin 目录（可选）
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

# 必须是干净的上游树；补丁只在这里应用一次
if [ -n "$(git status --porcelain -- . ':!KernelSU' 2>/dev/null | head -1)" ]; then
    die "$KSRC 不是干净的 $BRANCH 源码树（已有改动/已打过补丁）。请删除后重跑，或换一个 KSRC。"
fi

# ---------------------------------------------------------------- 补丁
# 注意：patches/*.patch 是 SuSFS 模式（KSU_SUSFS inline hook）。
# 旧的 0001-bakasu-manual-hooks.patch 与 SuSFS 补丁修改同一批文件、钩子实现互相冲突，
# 已移到 patches/manual-hooks/，默认不参与构建。
msg "应用补丁"
shopt -s nullglob
for p in "$HERE"/patches/*.patch; do
    name="$(basename "$p")"
    echo "  - $name"
    if patch -p1 --forward --batch --silent < "$p"; then
        continue
    fi
    # 补丁已在树上时，反向 dry-run 会成功
    if patch -p1 --reverse --dry-run --batch --silent < "$p" >/dev/null 2>&1; then
        echo "    (已应用，跳过)"
        continue
    fi
    die "补丁失败: $p
   最常见原因：KSRC 不是干净的 $BRANCH 源码树，或补丁顺序/模式不匹配。"
done

# 钩子存在性检查：缺了就说明补丁没打全，编出来的内核 root/susfs 会异常
check_hook() {
    grep -q "$1" "$2" 2>/dev/null || die "钩子缺失: $1 ($2) —— 补丁未正确应用"
}
msg "校验内核钩子"
check_hook ksu_handle_post_execveat_sucompat fs/exec.c
check_hook ksu_setup_preinit_file            fs/exec.c
check_hook ksu_handle_sys_read               fs/read_write.c
check_hook ksu_is_init_rc_hook_enabled       fs/read_write.c
check_hook ksu_is_input_hook_enabled         drivers/input/input.c
check_hook susfs_is_inode_sus_path           fs/namei.c
echo "  钩子检查通过"

# ---------------------------------------------------------------- BakaSU
msg "安装 BakaSU 源码"
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
command -v clang >/dev/null || die "找不到 clang，请设置 TC=/path/to/clang/bin 或把 clang 加入 PATH"
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

# ---------------------------------------------------------------- 配置
msg "生成 defconfig"
make "${MAKEFLAGS_COMMON[@]}" "$DEFCONFIG" < /dev/null

# 1) SuSFS 模式：KSU_SUSFS 与 KSU_MANUAL_HOOK / KSU_TRACEPOINT_HOOK 是 Kconfig choice 的
#    互斥项，必须只留一个。
# 2) 关 LTO/RELR：defconfig 里没有，但 syncconfig 会按 clang 默认值打开，
#    clang 15 的 ThinLTO bitcode 与系统 lld 版本不匹配会链接失败。
# 3) PICASSO 的 defconfig 有 LITTLE/BIG/PRIME_CPU_MASK 三个无默认值的 int 符号，
#    留空会触发 kconfig 交互式提问（无 tty 时死循环写日志），这里补上合法值。
./scripts/config --file .config \
    --set-val LITTLE_CPU_MASK 63 --set-val BIG_CPU_MASK 64 --set-val PRIME_CPU_MASK 128 \
    -e KSU -e KSU_SUSFS \
    -e KSU_SUSFS_SUS_PATH -e KSU_SUSFS_SUS_KSTAT -e KSU_SUSFS_SUS_MAP \
    -e KSU_SUSFS_SPOOF_UNAME -e KSU_SUSFS_ENABLE_LOG -e KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
    -d KSU_SUSFS_SUS_MOUNT -d KSU_SUSFS_OPEN_REDIRECT -d KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
    -d KSU_MANUAL_HOOK -d KSU_TRACEPOINT_HOOK \
    -d LTO_CLANG -d RELR -e COMPAT -d COMPAT_VDSO
make "${MAKEFLAGS_COMMON[@]}" olddefconfig < /dev/null

msg "校验最终配置"
grep -q '^CONFIG_KSU=y$'            .config || die "CONFIG_KSU 未启用"
grep -q '^CONFIG_KSU_SUSFS=y$'      .config || die "CONFIG_KSU_SUSFS 未启用（会退回无 hook 状态）"
grep -q '^CONFIG_KSU_SUSFS_SUS_PATH=y$' .config || die "CONFIG_KSU_SUSFS_SUS_PATH 未启用"
grep -q '^CONFIG_COMPAT=y$'         .config || die "CONFIG_COMPAT 未启用（32 位 su 会不可用）"
grep -q '^# CONFIG_KSU_MANUAL_HOOK is not set$' .config || \
    die "KSU_MANUAL_HOOK 与 KSU_SUSFS 同时开启（choice 冲突）"
grep -q '^# CONFIG_KSU_TRACEPOINT_HOOK is not set$' .config || \
    die "KSU_TRACEPOINT_HOOK 与 KSU_SUSFS 同时开启（choice 冲突）"
echo "  配置检查通过"

msg "编译内核（Image + dtbo.img）"
make "${MAKEFLAGS_COMMON[@]}" Image dtbo.img < /dev/null

# ---------------------------------------------------------------- 打包
msg "生成 dtb"
find arch/arm64/boot/dts/vendor/qcom -name '*.dtb' -print0 | sort -z | xargs -0 cat > arch/arm64/boot/dtb

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
  或用 AnyKernel3 把 Image + dtb + dtbo.img 打成 recovery 刷机包

  激活 root 需安装 BakaSU/ReSukiSU 管理器 APK (com.resukisu.resukisu)
  内核驱动版本应显示 v4.2.0-rc3-d5e9e025 (35252)，SuSFS 版本 v2.3.0
TIP
