#!/usr/bin/env bash
#
# Driftwood V4.1.0 build script - BakaSU + SuSFS kernel for Redmi K30 5G (picasso)
#
# Base: Akitlove/android_kernel_xiaomi_sm7250 @ da42a2f (4.19.325-cip133)
#
# Usage:
#   ./build.sh                      # fetch upstream, apply patches, build Image
#   KSRC=/path/to/tree ./build.sh   # reuse an existing kernel tree
#   BOOT_IMG=stock_boot.img ./build.sh   # also repack a boot.img with the new Image
#
# Requirements: clang/ld.lld (default ~/toolchains/clang23/bin), python3, git,
#               patch, make, bc, bison, flex, aarch64-linux-gnu-gcc
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-$HERE/build}"
KSRC="${KSRC:-$WORK/kernel-src}"
OUT="${OUT:-$HERE/out}"
UPSTREAM="${UPSTREAM:-https://github.com/Akitlove/android_kernel_xiaomi_sm7250}"
COMMIT="${COMMIT:-da42a2f}"
JOBS="${JOBS:-$(nproc)}"
TC="${TC:-$HOME/toolchains/clang23/bin}"
BOOT_IMG="${BOOT_IMG:-}"
CONFIG_SRC="$HERE/driftwood-v4.1.0.config"

PATCHES=(
  "0001-driftwood-v4.0.0-base.patch"
  "0005-palm-sensor-bounded-wait.patch"
  "0007-p-sensor-bounded-wait.patch"
  "0008-strip-compiler-urls.patch"
  "0009-btf-allow-zero-size-datasec.patch"
  "0010-per-proc-uname-spoof.patch"
)

msg() { printf '\n==> %s\n' "$*"; }
die() { printf '\n!! %s\n' "$*" >&2; exit 1; }

msg "preflight"
[ -x "$TC/clang" ] || die "clang not found in $TC (set TC=...)"
[ -f "$CONFIG_SRC" ] || die "missing config: $CONFIG_SRC"
mkdir -p "$OUT" "$WORK"

export PATH="$TC:$PATH"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_COMPAT=arm-linux-gnueabi-

if [ ! -f "$KSRC/Makefile" ]; then
  msg "fetching upstream $COMMIT"
  rm -rf "$KSRC"
  mkdir -p "$KSRC"
  TMP="$(mktemp -d)"
  curl -fL --retry 3 -o "$TMP/upstream.tar.gz" "$UPSTREAM/archive/$COMMIT.tar.gz"
  tar -xzf "$TMP/upstream.tar.gz" -C "$KSRC" --strip-components=1
  rm -rf "$TMP"
fi

# The repo vendors the BakaSU kernel source under kernel/; the kernel tree
# expects it at KernelSU/kernel (drivers/kernelsu is a symlink to it).
if [ ! -e "$KSRC/KernelSU/kernel/Kconfig" ]; then
  msg "installing vendored BakaSU source"
  rm -rf "$KSRC/KernelSU"
  mkdir -p "$KSRC/KernelSU/kernel"
  cp -a "$HERE/kernel/." "$KSRC/KernelSU/kernel/"
fi

cd "$KSRC"

apply_patch() {
  local p="$HERE/patches/$1"
  [ -f "$p" ] || die "missing patch: $p"
  if patch -p1 -R --dry-run -f -s < "$p" >/dev/null 2>&1; then
    msg "already applied: $1"
    return
  fi
  msg "applying $1"
  patch -p1 < "$p" || die "failed to apply $1"
}

for p in "${PATCHES[@]}"; do
  apply_patch "$p"
done

msg "installing config"
cp -f "$CONFIG_SRC" .config
make ARCH=arm64 CC=clang LD=ld.lld olddefconfig < /dev/null

msg "building Image (-j$JOBS)"
SECONDS=0
make ARCH=arm64 -j"$JOBS" CC=clang LD=ld.lld LLVM=1 LLVM_IAS=1 Image < /dev/null
echo "build took ${SECONDS}s"

cp -f arch/arm64/boot/Image "$OUT/Image"
msg "result"
ls -l "$OUT/Image"
sha256sum "$OUT/Image"
cat include/config/kernel.release

if [ -n "$BOOT_IMG" ]; then
  [ -f "$BOOT_IMG" ] || die "boot image not found: $BOOT_IMG"
  msg "repacking boot image"
  python3 "$HERE/tools/repack_boot.py" "$BOOT_IMG" "$OUT/Image" "$OUT/boot.img"
  sha256sum "$OUT/boot.img"
fi

msg "done"
