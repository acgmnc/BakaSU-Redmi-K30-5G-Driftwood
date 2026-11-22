#!/usr/bin/env bash
#
# Build SukiSU Nova + KernelPatch(KPM) + SuSFS 2.3.0 kernel for picasso
# (Redmi K30 5G), based on Akitlove susfs-miui (Linux 4.19.325-cip135-st19).
#
# Usage:
#   ./scripts/build-sukisu-nova.sh
#   KSRC=/path/to/tree ./scripts/build-sukisu-nova.sh
#   TC=/path/to/clang/bin JOBS=8 ./scripts/build-sukisu-nova.sh
#
# Output: out/Image-sukisu-nova
#
# Notes:
# - SukiSU Nova source is vendored as prebuilt/sukisu-nova-kernel-src.tar.gz
#   (kernel/ tree only, from SukiSU Nova "builtin-new" branch).
# - SuSFS 2.3.0 files come from the repo-level susfs-2.3.0-files.tar.gz.
# - KPM is force-enabled on 4.19 by relaxing the KSU_CAN_USE_KPM version gate;
#   KPM still needs KernelPatch at runtime (see scripts/patch-kpimg.sh).
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
WORK="${WORK:-$ROOT/build}"
KSRC="${KSRC:-$WORK/kernel-src}"
OUT="${OUT:-$ROOT/out}"
UPSTREAM="${UPSTREAM:-https://github.com/Akitlove/android_kernel_xiaomi_sm7250}"
BRANCH="${BRANCH:-susfs-miui}"
JOBS="${JOBS:-$(nproc)}"
TC="${TC:-$HOME/toolchains/clang23/bin}"

msg() { printf '\n==> %s\n' "$*"; }
die() { printf '\n!! %s\n' "$*" >&2; exit 1; }

[ -x "$TC/clang" ] || die "clang not found in $TC (set TC=...)"
mkdir -p "$OUT" "$WORK"
export PATH="$TC:$PATH"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_COMPAT=arm-linux-gnueabi-

msg "fetch kernel base ($BRANCH)"
if [ ! -f "$KSRC/Makefile" ]; then
  rm -rf "$KSRC"; mkdir -p "$KSRC"
  TMP="$(mktemp -d)"
  curl -fL --retry 3 -o "$TMP/src.tar.gz" "$UPSTREAM/archive/refs/heads/$BRANCH.tar.gz"
  tar -xzf "$TMP/src.tar.gz" -C "$KSRC" --strip-components=1
  rm -rf "$TMP"
fi

msg "install SukiSU Nova kernel source"
rm -rf "$KSRC/KernelSU"
mkdir -p "$KSRC/KernelSU/kernel"
tar -xzf "$ROOT/prebuilt/sukisu-nova-kernel-src.tar.gz" -C "$KSRC/KernelSU" --strip-components=1
rm -f "$KSRC/drivers/kernelsu"
ln -s ../KernelSU/kernel "$KSRC/drivers/kernelsu"
grep -q 'kernelsu' "$KSRC/drivers/Makefile" || printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> "$KSRC/drivers/Makefile"
grep -q 'drivers/kernelsu/Kconfig' "$KSRC/drivers/Kconfig" || \
  sed -i '/^endmenu/i source "drivers/kernelsu/Kconfig"' "$KSRC/drivers/Kconfig"

msg "install SuSFS 2.3.0 files"
tar -xzf "$ROOT/susfs-2.3.0-files.tar.gz" -C "$KSRC"

msg "add SuSFS 2.3.0 compatibility shims"
python3 - "$KSRC" <<'PY'
import io, sys
T = sys.argv[1]

# 1) header declarations
p = T + '/include/linux/susfs.h'
s = io.open(p, encoding='utf-8').read()
if 'susfs_set_sus_path_uid_filter' not in s:
    a = 'void susfs_set_priority_uid_filter(void __user **user_info);'
    s = s.replace(a, a + '\nvoid susfs_set_sus_path_uid_filter(void __user **user_info);'
                  + '\nvoid susfs_parse_sus_path_app_strings(void);'
                  + '\nint susfs_add_sus_type(const char *secctx, u32 type_value);'
                  + '\nint susfs_add_sus_avd_allowed_by_type(u32 s_type, u32 t_type, u32 c_type, u32 orig_avd_allowed);')
    io.open(p, 'w', encoding='utf-8').write(s)

# 2) command id used by SukiSU manager
p = T + '/include/linux/susfs_def.h'
s = io.open(p, encoding='utf-8').read()
if 'CMD_SUSFS_SET_SUS_PATH_UID_FILTER' not in s:
    a = '#define CMD_SUSFS_SET_PRIORITY_UID_FILTER 0x60030'
    s = s.replace(a, a + '\n#define CMD_SUSFS_SET_SUS_PATH_UID_FILTER 0x60031')
    io.open(p, 'w', encoding='utf-8').write(s)

# 3) stubs (SuSFS 2.3.0 does not implement these 2.4 APIs)
p = T + '/fs/susfs.c'
s = io.open(p, encoding='utf-8').read()
if 'susfs_add_sus_type' not in s:
    s += '''
/* Stubs: newer SuSFS 2.4 APIs (not implemented in this 2.3.0 port). */
void susfs_set_sus_path_uid_filter(void __user **user_info) { (void)user_info; }
void susfs_parse_sus_path_app_strings(void) { }
int susfs_add_sus_type(const char *secctx, u32 type_value) { (void)secctx; (void)type_value; return 0; }
int susfs_add_sus_avd_allowed_by_type(u32 s_type, u32 t_type, u32 c_type, u32 orig_avd_allowed)
{ (void)s_type; (void)t_type; (void)c_type; (void)orig_avd_allowed; return 0; }
'''
    io.open(p, 'w', encoding='utf-8').write(s)

# 4) statfs wrappers
p = T + '/fs/statfs.c'
s = io.open(p, encoding='utf-8').read()
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
#endif /* CONFIG_KSU_SUSFS */

'''
    i = s.find('int vfs_statfs(')
    s = s[:i] + add + s[i:]
    io.open(p, 'w', encoding='utf-8').write(s)
print('shims ok')
PY

msg "force KPM on 4.19"
sed -i 's/#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 10, 0)/#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 19, 0)/' \
  "$KSRC/drivers/kernelsu/kernel_compat.h"

msg "patch compiler URL (0008)"
patch -p1 -N --forward -s -d "$KSRC" < "$ROOT/patches/0008-strip-compiler-urls.patch" || true

msg "config"
cp -f "$ROOT/driftwood-v4.2.0-sukisu.config" "$KSRC/.config"
make -C "$KSRC" ARCH=arm64 CC=clang LD=ld.lld olddefconfig < /dev/null

msg "include flags"
for d in techpack/camera/drivers/cam_sensor_module/cam_cci drivers/clk/qcom drivers/xiaomi techpack/display/pll; do
  mk="$KSRC/$d/Makefile"
  [ -f "$mk" ] || continue
  grep -q 'ccflags-y += -I\$(src)' "$mk" || printf '\nccflags-y += -I$(src)\n' >> "$mk"
done

msg "build Image (-j$JOBS)"
SECONDS=0
make -C "$KSRC" ARCH=arm64 -j"$JOBS" CC=clang LD=ld.lld LLVM=1 LLVM_IAS=1 Image < /dev/null
echo "build took ${SECONDS}s"

cp -f "$KSRC/arch/arm64/boot/Image" "$OUT/Image-sukisu-nova"
ls -l "$OUT/Image-sukisu-nova"
sha256sum "$OUT/Image-sukisu-nova"
cat "$KSRC/include/config/kernel.release"

msg "next: run scripts/patch-kpimg.sh to inject KernelPatch + KPM support"
