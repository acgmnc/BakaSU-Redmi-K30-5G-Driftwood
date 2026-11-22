#!/usr/bin/env bash
#
# Inject KernelPatch into a kernel Image and package an AnyKernel3 zip.
#
# Why: SukiSU's KPM is only a bridge. It looks up __arm64_sys_truncate and
# sends a magic supercall; the actual KPM loader lives in KernelPatch (KP).
# Official KernelPatch does NOT understand SukiSU's KPM magic, so the
# SukiSU-specific KernelPatch fork must be used:
#
#   https://github.com/SukiSU-Nova/SukiSU_KernelPatch_patch
#
# The released kpimg (0.11-beta, 2025-06) predates the KPM ABI v2
# (2026-11), so kpimg must be BUILT FROM SOURCE with an ARM bare-metal
# toolchain (aarch64-none-elf-gcc). Clang / Linux-targeted GCC produce an
# oversized .setup.map and the kpimg linker script aborts.
#
# Usage:
#   ./scripts/patch-kpimg.sh out/Image-sukisu-nova [superkey] [out_ak3.zip]
#
# Environment:
#   TC_ELF  path prefix of the bare-metal toolchain
#           (default: aarch64-none-elf-, i.e. from PATH)
#   KP_SRC  KernelPatch source dir (downloaded when missing)
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
WORK="${WORK:-$ROOT/build}"
KP_SRC="${KP_SRC:-$WORK/SukiSU_KernelPatch_patch}"
TC_ELF="${TC_ELF:-aarch64-none-elf-}"
SUPERKEY="${2:-DriftwoodKp2026}"
IMAGE="${1:?usage: patch-kpimg.sh <Image> [superkey] [out.zip]}"
OUT_ZIP="${3:-$ROOT/out/SukiSU-KP-KPM-ak3.zip}"
KP_REPO="https://codeload.github.com/SukiSU-Nova/SukiSU_KernelPatch_patch/tar.gz/refs/heads/main"

msg() { printf '\n==> %s\n' "$*"; }
die() { printf '\n!! %s\n' "$*" >&2; exit 1; }

[ -f "$IMAGE" ] || die "Image not found: $IMAGE"
command -v "${TC_ELF}gcc" >/dev/null 2>&1 || \
  die "${TC_ELF}gcc not found. Download Arm GNU Toolchain (aarch64-none-elf) and set TC_ELF=/path/bin/aarch64-none-elf-"

mkdir -p "$WORK" "$ROOT/out"

msg "fetch SukiSU KernelPatch source"
if [ ! -f "$KP_SRC/kernel/Makefile" ]; then
  TMP="$(mktemp -d)"
  curl -fL --retry 3 -o "$TMP/kp.tar.gz" "$KP_REPO"
  mkdir -p "$KP_SRC"
  tar -xzf "$TMP/kp.tar.gz" -C "$KP_SRC" --strip-components=1
  rm -rf "$TMP"
fi
grep -E '#define (MAJOR|MINOR|PATCH)' "$KP_SRC/version" || true

msg "build kpimg (bare-metal, ANDROID config)"
make -C "$KP_SRC/kernel" clean >/dev/null 2>&1 || true
make -C "$KP_SRC/kernel" TARGET_COMPILE="$TC_ELF" ANDROID=1 -j"$(nproc)"
[ -f "$KP_SRC/kernel/kpimg" ] || die "kpimg build failed"
ls -l "$KP_SRC/kernel/kpimg"

msg "build kptools"
make -C "$KP_SRC/tools" -j"$(nproc)"
[ -x "$KP_SRC/tools/kptools" ] || die "kptools build failed"

msg "patch Image with kpimg"
"$KP_SRC/tools/kptools" -p -i "$IMAGE" -k "$KP_SRC/kernel/kpimg" -s "$SUPERKEY" \
  -o "$ROOT/out/Image-kp"
"$KP_SRC/tools/kptools" -l -i "$ROOT/out/Image-kp" | head -12

if [ -x "$HERE/pack-ak3.sh" ]; then
  msg "pack AnyKernel3"
  bash "$HERE/pack-ak3.sh" "$ROOT/out/Image-kp" "$OUT_ZIP"
fi

msg "done"
