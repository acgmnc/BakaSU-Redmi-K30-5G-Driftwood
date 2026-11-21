#!/usr/bin/env bash
#
# Driftwood V4.2.0 build script - BakaSU + SuSFS 2.3.0 for Redmi K30 5G (picasso)
#
# Base: Akitlove/android_kernel_xiaomi_sm7250 branch susfs-miui
#       (Linux 4.19.325-cip135-st19)
#
# Usage:
#   ./build.sh                          # full build
#   KSRC=/path/to/tree ./build.sh       # reuse an existing tree
#   BOOT_IMG=stock_boot.img ./build.sh  # also repack a boot.img
#   TC=/path/to/clang/bin ./build.sh    # custom toolchain
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-$HERE/build}"
KSRC="${KSRC:-$WORK/kernel-src}"
OUT="${OUT:-$HERE/out}"
UPSTREAM="${UPSTREAM:-https://github.com/Akitlove/android_kernel_xiaomi_sm7250}"
BRANCH="${BRANCH:-susfs-miui}"
JOBS="${JOBS:-$(nproc)}"
TC="${TC:-$HOME/toolchains/clang23/bin}"
BOOT_IMG="${BOOT_IMG:-}"
CONFIG_SRC="$HERE/driftwood-v4.2.0.config"

msg() { printf '\n==> %s\n' "$*"; }
die() { printf '\n!! %s\n' "$*" >&2; exit 1; }

[ -x "$TC/clang" ] || die "clang not found in $TC (set TC=...)"
[ -f "$CONFIG_SRC" ] || die "missing config: $CONFIG_SRC"
mkdir -p "$OUT" "$WORK"

export PATH="$TC:$PATH"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_COMPAT=arm-linux-gnueabi-

if [ ! -f "$KSRC/Makefile" ]; then
  msg "fetching upstream $BRANCH"
  rm -rf "$KSRC"; mkdir -p "$KSRC"
  TMP="$(mktemp -d)"
  curl -fL --retry 3 -o "$TMP/src.tar.gz" "$UPSTREAM/archive/refs/heads/$BRANCH.tar.gz"
  tar -xzf "$TMP/src.tar.gz" -C "$KSRC" --strip-components=1
  rm -rf "$TMP"
fi

msg "installing BakaSU source"
rm -rf "$KSRC/KernelSU"
mkdir -p "$KSRC/KernelSU/kernel"
cp -a "$HERE/kernel/." "$KSRC/KernelSU/kernel/"
rm -f "$KSRC/drivers/kernelsu"
ln -s ../KernelSU/kernel "$KSRC/drivers/kernelsu"

msg "installing SuSFS 2.3.0 files"
tar -xzf "$HERE/susfs-2.3.0-files.tar.gz" -C "$KSRC"

msg "applying patches"
cd "$KSRC"
for p in "$HERE"/patches/*.patch; do
  [ -f "$p" ] || continue
  patch -p1 -N --forward -s < "$p" || die "patch failed: $p"
done

msg "adding statfs wrappers"
python3 - "$KSRC/fs/statfs.c" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
if 'statfs_by_dentry_wrapper' not in s:
    add = '''#ifdef CONFIG_KSU_SUSFS
int statfs_by_dentry_wrapper(struct dentry *dentry, struct kstatfs *buf)
{
\treturn statfs_by_dentry(dentry, buf);
}

int calculate_f_flags_wrapper(struct vfsmount *mnt)
{
\treturn calculate_f_flags(mnt);
}
#endif // #ifdef CONFIG_KSU_SUSFS

'''
    idx = s.find('int vfs_statfs(')
    assert idx > 0, "vfs_statfs anchor not found"
    open(p, 'w').write(s[:idx] + add + s[idx:])
    print("wrappers added")
else:
    print("wrappers already present")
PY

msg "adding include flags"
for d in techpack/camera/drivers/cam_sensor_module/cam_cci drivers/clk/qcom drivers/xiaomi techpack/display/pll; do
  mk="$KSRC/$d/Makefile"
  [ -f "$mk" ] || continue
  grep -q 'ccflags-y += -I\$(src)' "$mk" || printf '\nccflags-y += -I$(src)\n' >> "$mk"
done

msg "installing config"
cp -f "$CONFIG_SRC" "$KSRC/.config"
make -C "$KSRC" ARCH=arm64 CC=clang LD=ld.lld olddefconfig < /dev/null

msg "building Image (-j$JOBS)"
SECONDS=0
make -C "$KSRC" ARCH=arm64 -j"$JOBS" CC=clang LD=ld.lld LLVM=1 LLVM_IAS=1 Image < /dev/null
echo "build took ${SECONDS}s"

cp -f "$KSRC/arch/arm64/boot/Image" "$OUT/Image"
msg "result"
ls -l "$OUT/Image"
sha256sum "$OUT/Image"
cat "$KSRC/include/config/kernel.release"

if [ -n "$BOOT_IMG" ]; then
  [ -f "$BOOT_IMG" ] || die "boot image not found: $BOOT_IMG"
  msg "repacking boot image"
  python3 "$HERE/tools/repack_boot.py" "$BOOT_IMG" "$OUT/Image" "$OUT/boot.img"
  sha256sum "$OUT/boot.img"
fi

msg "done"
