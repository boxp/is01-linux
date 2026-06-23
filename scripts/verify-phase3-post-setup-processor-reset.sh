#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

out_dir='build/phase3/post-setup-processor-reset'
kernel_out=${KERNEL_OUT:-build/phase3/post-setup-processor-reset-kernel-out}
zimage="$kernel_out/arch/arm/boot/zImage"
ramdisk='build/phase3/initramfs/initramfs.cpio'
padded_kernel="$out_dir/phase3-post-setup-processor-reset-stock-kernel-slot.bin"
padded_ramdisk="$out_dir/phase3-initramfs-stock-ramdisk-slot.cpio"
boot_img="$out_dir/phase3-stockslot-post-setup-processor-reset-boot.img"
recovery_img="$out_dir/phase3-stockslot-post-setup-processor-reset-recovery.img"
patch_note="$out_dir/post-setup-processor-reset-patch.txt"
stock_kernel_size=5526688
stock_ramdisk_size=791552
partition_size=11534336

test -s "$zimage" || fail "missing $zimage"
test -s "$ramdisk" || fail "missing $ramdisk"
test -s "$padded_kernel" || fail "missing $padded_kernel"
test -s "$padded_ramdisk" || fail "missing $padded_ramdisk"
test -s "$boot_img" || fail "missing $boot_img"
test -s "$recovery_img" || fail "missing $recovery_img"
test -s "$patch_note" || fail "missing $patch_note"

[ "$(wc -c <"$padded_kernel")" -eq "$stock_kernel_size" ] || fail 'padded kernel slot size mismatch'
[ "$(wc -c <"$padded_ramdisk")" -eq "$stock_ramdisk_size" ] || fail 'padded ramdisk slot size mismatch'
[ "$(wc -c <"$recovery_img")" -eq "$partition_size" ] || fail 'recovery image size mismatch'

grep -F 'proc_comm reset' "$patch_note" >/dev/null || fail 'patch note does not describe proc_comm reset'

python3 - "$zimage" "$padded_kernel" "$ramdisk" "$padded_ramdisk" <<'PY'
from pathlib import Path
import struct
import sys

zimage = Path(sys.argv[1]).read_bytes()
padded_kernel = Path(sys.argv[2]).read_bytes()
ramdisk = Path(sys.argv[3]).read_bytes()
padded_ramdisk = Path(sys.argv[4]).read_bytes()
if not padded_kernel.startswith(zimage):
    raise SystemExit("error: padded kernel slot does not start with patched zImage")
if not padded_ramdisk.startswith(ramdisk):
    raise SystemExit("error: padded ramdisk slot does not start with Phase 3 initramfs")
if len(zimage) < 48:
    raise SystemExit("error: patched zImage is too small")
magic = struct.unpack_from("<I", zimage, 36)[0]
if magic != 0x016F2818:
    raise SystemExit(f"error: patched zImage magic mismatch: 0x{magic:08x}")
PY

./scripts/inspect-android-bootimg.py \
  --image-align-size 4096 \
  --expect-page-size 2048 \
  --expect-align-size 4096 \
  --expect-kernel-addr 0x20008000 \
  --expect-ramdisk-addr 0x24000000 \
  --expect-second-addr 0x20f00000 \
  --expect-tags-addr 0x20000100 \
  --expect-cmdline-contains 'rdinit=/init' \
  --expect-cmdline-contains 'panic=20' \
  "$boot_img" >"$out_dir/VERIFY-BOOT-LAYOUT.txt"

./scripts/verify-phase3-initramfs.sh

sha256sum "$zimage" "$boot_img" "$recovery_img" >"$out_dir/VERIFY-SHA256SUMS"

printf 'Phase 3 post-setup-processor reset candidate verified:\n'
cat "$out_dir/VERIFY-SHA256SUMS"
