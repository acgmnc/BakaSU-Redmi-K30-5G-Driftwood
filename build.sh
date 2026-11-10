#!/usr/bin/env bash
#
# 构建 BakaSU + SuSFS + Driftwood 内核 for Redmi K30 5G (picasso)
#
# 用法:
#   ./build.sh                                  # 拉源码、打补丁、编译并整理产物
#   KSRC=/path/to/kernel ./build.sh             # 复用锁定版本的源码树
#   URL_BOOT=stock_boot.img ./build.sh          # 额外重打包 boot.img（相对路径按调用时的目录解析）
#
# 环境要求:
#   - clang 15 + LLD 15（自定义目录可用 TC=/path/to/clang/bin）
#   - python3, git, patch, make, bc, bison, flex, aarch64-linux-gnu-gcc
#   - libssl-dev, libelf-dev 及常用内核构建依赖
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-$HERE/build}"
KSRC="${KSRC:-$WORK/kernel-src}"
UPSTREAM="${UPSTREAM:-https://github.com/HeinUmin/kernel_xiaomi_sm7250.git}"
BRANCH="${BRANCH:-android-4.19}"
JOBS="${JOBS:-$(nproc)}"
TC="${TC:-}"
URL_BOOT="${URL_BOOT:-}"
DEFCONFIG="vendor/picasso_user_defconfig"
TARGET_GCC="aarch64-linux-gnu-"

msg() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

# 先规范化调用者提供的路径，避免后续 cd 到 KSRC 后相对路径改变含义。
command -v realpath >/dev/null || die "找不到 realpath"
mkdir -p "$WORK"
WORK="$(realpath -e -- "$WORK")" || die "无法解析 WORK 路径"
KSRC="$(realpath -m -- "$KSRC")" || die "无法解析 KSRC 路径"

if [ -n "$URL_BOOT" ]; then
    [ -f "$URL_BOOT" ] || die "URL_BOOT 文件不存在: $URL_BOOT"
    URL_BOOT="$(realpath -e -- "$URL_BOOT")" || die "无法解析 URL_BOOT 路径"
fi

if [ -n "$TC" ]; then
    [ -d "$TC" ] || die "TC 目录不存在: $TC"
    TC="$(realpath -e -- "$TC")" || die "无法解析 TC 路径"
    export PATH="$TC:$PATH"
fi

for tool in git patch make python3 bc bison flex realpath find sort cat awk sed grep diff sha256sum nproc clang ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-strip aarch64-linux-gnu-gcc; do
    command -v "$tool" >/dev/null || die "找不到构建依赖: $tool"
done

if [[ "$(clang --version | head -1)" =~ version[[:space:]]([0-9]+) ]]; then
    CLANG_MAJOR="${BASH_REMATCH[1]}"
else
    die "无法识别 clang 版本"
fi
if [[ "$(ld.lld --version | head -1)" =~ LLD[[:space:]]([0-9]+) ]]; then
    LLD_MAJOR="${BASH_REMATCH[1]}"
else
    die "无法识别 ld.lld 版本"
fi
[ "$CLANG_MAJOR" = "$LLD_MAJOR" ] || die "clang $CLANG_MAJOR 与 ld.lld $LLD_MAJOR 主版本不匹配"
if [ "$CLANG_MAJOR" != "15" ]; then
    echo "警告: 当前机型已验证 clang 15；其他 Clang 版本可能无法正常启动"
fi

KERNEL_COMMIT="${KERNEL_COMMIT:-$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["kernel_commit"])' "$HERE/upstream.lock")}"
[[ "$KERNEL_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "upstream.lock 中的 kernel_commit 不是有效的 40 位 commit SHA"

# ---------------------------------------------------------------- 源码
if git -C "$KSRC" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    msg "复用已有源码树: $KSRC"
else
    if [ -e "$KSRC" ] && [ -n "$(find "$KSRC" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
        die "KSRC 已存在但不是 Git 工作树，拒绝覆盖: $KSRC"
    fi
    mkdir -p "$(dirname "$KSRC")"
    msg "拉取上游源码 ($UPSTREAM @ $BRANCH)"
    git clone --depth=1 -b "$BRANCH" "$UPSTREAM" "$KSRC" || die "上游源码克隆失败"
    cloned_commit="$(git -C "$KSRC" rev-parse HEAD)"
    if [ "$cloned_commit" != "$KERNEL_COMMIT" ]; then
        msg "切换到 upstream.lock 锁定的内核 commit"
        git -C "$KSRC" fetch --depth=1 origin "$KERNEL_COMMIT" || die "无法获取锁定的内核 commit: $KERNEL_COMMIT"
        git -C "$KSRC" checkout --detach "$KERNEL_COMMIT" || die "无法检出锁定的内核 commit"
    fi
fi
cd "$KSRC"

repo_root="$(git rev-parse --show-toplevel)"
[ "$repo_root" = "$KSRC" ] || die "KSRC 必须是 Git 仓库根目录"
actual_origin="$(git remote get-url origin 2>/dev/null)" || die "KSRC 缺少 origin remote"
normalize_git_url() {
    local value="$1"
    value="${value%.git}"
    printf '%s\n' "${value%/}"
}
[ "$(normalize_git_url "$actual_origin")" = "$(normalize_git_url "$UPSTREAM")" ] || \
    die "KSRC 的 origin 与 UPSTREAM 不匹配: $actual_origin"
actual_commit="$(git rev-parse HEAD)"
[ "$actual_commit" = "$KERNEL_COMMIT" ] || \
    die "KSRC commit 不匹配：期望 $KERNEL_COMMIT，实际 $actual_commit。请使用锁定版本的干净源码树。"
current_branch="$(git branch --show-current)"
if [ -n "$current_branch" ] && [ "$current_branch" != "$BRANCH" ]; then
    die "KSRC 分支不匹配：期望 $BRANCH，实际 $current_branch"
fi

# 只接受本项目补丁、KSU 接入和本脚本生成的文件变化。
shopt -s nullglob
PATCH_FILES=("$HERE"/patches/*.patch)
for required_patch in \
    0002-trace-include-paths.patch \
    0003-build-fixes.patch \
    0004-headers-shims.patch \
    0005-palm-sensor-bounded-wait.patch \
    0006-susfs-v2.3.0-4.19.patch; do
    [ -f "$HERE/patches/$required_patch" ] || die "缺少默认构建补丁: $required_patch"
done

declare -A ALLOWED_TRACKED=()
declare -A ALLOWED_NEW=()
ALLOWED_TRACKED["drivers/Makefile"]=1
ALLOWED_TRACKED["drivers/Kconfig"]=1
for patch_file in "${PATCH_FILES[@]}"; do
    while IFS= read -r path; do
        path="${path%%$'\t'*}"
        [ -n "$path" ] && ALLOWED_TRACKED["$path"]=1
    done < <(sed -n 's|^+++ b/||p' "$patch_file")

    while IFS= read -r path; do
        [ -n "$path" ] && ALLOWED_NEW["$path"]=1
    done < <(awk '
        /^--- \/dev\/null([[:space:]]|$)/ { creating=1; next }
        /^--- / { creating=0; next }
        creating && /^\+\+\+ b\// {
            sub(/^\+\+\+ b\//, "")
            sub(/\t.*/, "")
            print
            creating=0
        }
    ' "$patch_file")
done
for generated in arch/arm64/boot/Image arch/arm64/boot/dtb arch/arm64/boot/dtbo.img; do
    ALLOWED_NEW["$generated"]=1
done

git diff --cached --quiet || die "KSRC 有暂存修改，拒绝继续"
while IFS= read -r path; do
    [ -n "$path" ] || continue
    [[ -n "${ALLOWED_TRACKED[$path]+yes}" ]] || die "KSRC 有非构建脚本产生的修改，拒绝继续: $path"
done < <(git diff --name-only)
while IFS= read -r -d '' path; do
    case "$path" in
        KernelSU/*|drivers/kernelsu) continue ;;
    esac
    [[ -n "${ALLOWED_NEW[$path]+yes}" ]] || die "KSRC 有未知未跟踪文件，拒绝继续: $path"
done < <(git ls-files --others --exclude-standard -z)

# ---------------------------------------------------------------- 补丁
# patches/*.patch 是 SuSFS inline-hook 模式。0001 手动 Hook 补丁在
# patches/manual-hooks/，不匹配此 glob，默认不会应用。
msg "应用补丁"
for p in "${PATCH_FILES[@]}"; do
    name="$(basename "$p")"
    echo "  - $name"
    if patch -p1 --forward --batch --silent < "$p"; then
        continue
    fi
    if patch -p1 --reverse --dry-run --batch --silent < "$p" >/dev/null 2>&1; then
        echo "    (已应用，跳过)"
        continue
    fi
    die "补丁失败: $p\n   请使用锁定 commit 的干净 $BRANCH 源码树；失败后先检查并清理 .rej 文件。"
done

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
if [ -e KernelSU ] || [ -L KernelSU ]; then
    [ -d KernelSU ] && [ ! -L KernelSU ] || die "KernelSU 路径不是预期目录，拒绝覆盖"
    [ -d KernelSU/kernel ] && [ ! -L KernelSU/kernel ] || die "KernelSU/kernel 不存在或不是普通目录"
    extra_ksu_entry="$(find KernelSU -mindepth 1 -maxdepth 1 ! -name kernel -print -quit)"
    [ -z "$extra_ksu_entry" ] || die "KernelSU 中存在非本脚本管理的内容，拒绝删除: $extra_ksu_entry"
    diff -qr -- "$HERE/kernel" KernelSU/kernel >/dev/null || \
        die "现有 KernelSU/kernel 与仓库快照不同，拒绝覆盖"
else
    mkdir -p KernelSU
    cp -a "$HERE/kernel" KernelSU/kernel
fi

if [ -L drivers/kernelsu ]; then
    [ "$(readlink drivers/kernelsu)" = "../KernelSU/kernel" ] || \
        die "drivers/kernelsu 是指向其他位置的链接，拒绝覆盖"
elif [ -e drivers/kernelsu ]; then
    die "drivers/kernelsu 已存在且不是本脚本创建的符号链接，拒绝覆盖"
else
    ln -s ../KernelSU/kernel drivers/kernelsu
fi

if ! grep -Eq '^[[:space:]]*obj-\$\(CONFIG_KSU\)[[:space:]]*[+]=[[:space:]]*kernelsu[/]?[[:space:]]*$' drivers/Makefile; then
    printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> drivers/Makefile
fi
if ! grep -Fxq 'source "drivers/kernelsu/Kconfig"' drivers/Kconfig; then
    printf '\nsource "drivers/kernelsu/Kconfig"\n' >> drivers/Kconfig
fi

# ---------------------------------------------------------------- 工具链
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

# SuSFS inline hook 与手动/tracepoint hook 互斥。CPU mask 必须有合法默认值。
./scripts/config --file .config \
    --set-val LITTLE_CPU_MASK 63 --set-val BIG_CPU_MASK 64 --set-val PRIME_CPU_MASK 128 \
    -e KSU -e KSU_SUSFS \
    -e KSU_SUSFS_SUS_PATH -e KSU_SUSFS_SUS_MOUNT -e KSU_SUSFS_SUS_KSTAT -e KSU_SUSFS_SUS_MAP \
    -e KSU_SUSFS_SPOOF_UNAME -e KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG -e KSU_SUSFS_OPEN_REDIRECT \
    -e KSU_SUSFS_ENABLE_LOG -e KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
    -d KSU_MANUAL_HOOK -d KSU_TRACEPOINT_HOOK \
    -d LTO_CLANG -d RELR -e COMPAT -d COMPAT_VDSO
make "${MAKEFLAGS_COMMON[@]}" olddefconfig < /dev/null

msg "校验最终配置"
grep -q '^CONFIG_KSU=y$' .config || die "CONFIG_KSU 未启用"
grep -q '^CONFIG_KSU_SUSFS=y$' .config || die "CONFIG_KSU_SUSFS 未启用"
grep -q '^CONFIG_COMPAT=y$' .config || die "CONFIG_COMPAT 未启用（32 位 su 会不可用）"
grep -q '^# CONFIG_COMPAT_VDSO is not set$' .config || die "CONFIG_COMPAT_VDSO 必须关闭"
grep -q '^# CONFIG_LTO_CLANG is not set$' .config || die "CONFIG_LTO_CLANG 必须关闭"
grep -q '^# CONFIG_RELR is not set$' .config || die "CONFIG_RELR 必须关闭"
grep -q '^CONFIG_LITTLE_CPU_MASK=63$' .config || die "LITTLE_CPU_MASK 值不正确"
grep -q '^CONFIG_BIG_CPU_MASK=64$' .config || die "BIG_CPU_MASK 值不正确"
grep -q '^CONFIG_PRIME_CPU_MASK=128$' .config || die "PRIME_CPU_MASK 值不正确"

for option in \
    KSU_SUSFS_SUS_PATH \
    KSU_SUSFS_SUS_MOUNT \
    KSU_SUSFS_SUS_KSTAT \
    KSU_SUSFS_SUS_MAP \
    KSU_SUSFS_SPOOF_UNAME \
    KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
    KSU_SUSFS_OPEN_REDIRECT \
    KSU_SUSFS_ENABLE_LOG \
    KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS; do
    grep -q "^CONFIG_${option}=y$" .config || die "CONFIG_${option} 未启用"
done

grep -q '^# CONFIG_KSU_MANUAL_HOOK is not set$' .config || \
    die "KSU_MANUAL_HOOK 与 KSU_SUSFS 同时开启（choice 冲突）"
grep -q '^# CONFIG_KSU_TRACEPOINT_HOOK is not set$' .config || \
    die "KSU_TRACEPOINT_HOOK 与 KSU_SUSFS 同时开启（choice 冲突）"
echo "  配置检查通过"

# ---------------------------------------------------------------- 编译
msg "编译内核（Image + dtbo.img）"
make "${MAKEFLAGS_COMMON[@]}" Image dtbo.img < /dev/null
[ -s arch/arm64/boot/Image ] || die "Image 未生成或为空"
[ -s arch/arm64/boot/dtbo.img ] || die "dtbo.img 未生成或为空"

# ---------------------------------------------------------------- 打包
msg "生成 dtb"
DTB_DIR=arch/arm64/boot/dts/vendor/qcom
[ -d "$DTB_DIR" ] || die "DTB 目录不存在: $DTB_DIR"
mapfile -d '' DTB_FILES < <(find "$DTB_DIR" -type f -name '*.dtb' -print0 | sort -z)
if (("${#DTB_FILES[@]}" == 0)); then
    die "没有找到可打包的 Qualcomm DTB"
fi
for dtb_file in "${DTB_FILES[@]}"; do
    [ -s "$dtb_file" ] || die "DTB 文件为空: $dtb_file"
done
cat -- "${DTB_FILES[@]}" > arch/arm64/boot/dtb
[ -s arch/arm64/boot/dtb ] || die "合并后的 dtb 为空"

OUT="$(realpath -m -- "$WORK/out")"
case "$OUT/" in
    "$KSRC/"*) die "产物目录不能位于 KSRC 内: $OUT" ;;
esac
case "$KSRC/" in
    "$OUT/"*) die "产物目录不能包含 KSRC: $OUT" ;;
esac
mkdir -p "$OUT"
OUT="$(realpath -e -- "$OUT")"
# 只清理本脚本管理的文件，不递归删除用户指定的输出目录。
rm -f -- "$OUT/Image" "$OUT/dtbo.img" "$OUT/dtb" "$OUT/boot.img"
cp -f arch/arm64/boot/Image "$OUT/Image"
cp -f arch/arm64/boot/dtbo.img "$OUT/dtbo.img"
cp -f arch/arm64/boot/dtb "$OUT/dtb"

if [ -n "$URL_BOOT" ]; then
    msg "重打包 boot.img"
    python3 "$HERE/tools/repack_boot.py" \
        "$URL_BOOT" "$OUT/Image" "$OUT/boot.img" "$OUT/dtb"
    [ -s "$OUT/boot.img" ] || die "boot.img 未生成或为空"
fi

msg "完成"
echo "产物目录: $OUT"
ls -lh "$OUT"
echo
if [ -f "$OUT/boot.img" ]; then
    echo "  fastboot flash boot \"$OUT/boot.img\""
else
    echo "  未生成 boot.img；如需重打包，请用 URL_BOOT=/absolute/path/to/stock_boot.img ./build.sh"
fi
echo "  或用 AnyKernel3 把 Image + dtb + dtbo.img 打成 recovery 刷机包"
echo
echo "  激活 root 需安装 BakaSU/ReSukiSU 管理器 APK (com.resukisu.resukisu)"
echo "  内核驱动版本应显示 v4.2.0-rc3-d5e9e025 (35252)，SuSFS 版本 v2.3.0"
