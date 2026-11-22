#!/usr/bin/env bash
#
# Pack an AnyKernel3 zip for Redmi K30 5G (picasso) from a raw kernel Image.
#
# Usage:
#   ./scripts/pack-ak3.sh [Image] [out.zip]
#     Image     default: out/Image
#     out.zip   default: out/BakaSU-picasso-Driftwood-V4.2.0-ak3.zip
#
# Notes:
# - Kernel is packed as Image.gz (this device's ABL expects the gzip kernel
#   format used by the stock A17 boot image).
# - The package intentionally contains no dtb/dtbo.img: on devices with a
#   vendor_boot partition, AnyKernel3's auto-layout would move Image into
#   boot-files/ and keep the stock kernel, and would also flash a foreign dtbo.
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
IMAGE="${1:-$ROOT/out/Image}"
OUT="${2:-$ROOT/out/BakaSU-picasso-Driftwood-V4.2.0-ak3.zip}"
TEMPLATE_URL="${TEMPLATE_URL:-https://github.com/osm0sis/AnyKernel3/archive/refs/heads/master.zip}"

[ -f "$IMAGE" ] || { echo "missing Image: $IMAGE" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> downloading AnyKernel3 template"
curl -fL --retry 3 -o "$TMP/ak3.zip" "$TEMPLATE_URL"
unzip -q "$TMP/ak3.zip" -d "$TMP/ak3"
AK="$(find "$TMP/ak3" -maxdepth 1 -mindepth 1 -type d | head -n1)"
[ -n "$AK" ] || { echo "template extract failed" >&2; exit 1; }

echo "==> installing anykernel.sh"
cp -f "$HERE/anykernel.sh" "$AK/anykernel.sh"

echo "==> packing kernel as Image.gz"
gzip -9 -n -c "$IMAGE" > "$AK/Image.gz"
rm -f "$AK/Image" "$AK/dtb" "$AK/dtbo.img"

echo "==> creating zip"
( cd "$AK" && zip -q -r -y "$OUT" . )

echo "==> result"
ls -l "$OUT"
sha256sum "$OUT"
