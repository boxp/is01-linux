#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

out_dir='build/phase3/stockslot-no-reset-boot'
kernel_out=${KERNEL_OUT:-build/phase3/stockslot-no-reset-boot-kernel-out}
zimage="$kernel_out/arch/arm/boot/zImage"
ramdisk='build/phase3/initramfs/initramfs.cpio'
padded_kernel="$out_dir/phase3-stockslot-no-reset-boot-stock-kernel-slot.bin"
padded_ramdisk="$out_dir/phase3-initramfs-stock-ramdisk-slot.cpio"
boot_img="$out_dir/phase3-stockslot-no-reset-boot.img"
recovery_img="$out_dir/phase3-stockslot-no-reset-boot-recovery.img"
stock_kernel_size=5526688
stock_ramdisk_size=791552
partition_size=11534336

test -s "$zimage" || fail "missing $zimage"
test -s "$ramdisk" || fail "missing $ramdisk"
test -s "$padded_kernel" || fail "missing $padded_kernel"
test -s "$padded_ramdisk" || fail "missing $padded_ramdisk"
test -s "$boot_img" || fail "missing $boot_img"
test -s "$recovery_img" || fail "missing $recovery_img"

[ "$(wc -c <"$padded_kernel")" -eq "$stock_kernel_size" ] || fail 'padded kernel slot size mismatch'
[ "$(wc -c <"$padded_ramdisk")" -eq "$stock_ramdisk_size" ] || fail 'padded ramdisk slot size mismatch'
[ "$(wc -c <"$recovery_img")" -eq "$partition_size" ] || fail 'recovery image size mismatch'

python3 - "$zimage" "$padded_kernel" "$ramdisk" "$padded_ramdisk" <<'PY'
from pathlib import Path
import struct
import sys

zimage = Path(sys.argv[1]).read_bytes()
padded_kernel = Path(sys.argv[2]).read_bytes()
ramdisk = Path(sys.argv[3]).read_bytes()
padded_ramdisk = Path(sys.argv[4]).read_bytes()
if not padded_kernel.startswith(zimage):
    raise SystemExit("error: padded kernel slot does not start with zImage")
if not padded_ramdisk.startswith(ramdisk):
    raise SystemExit("error: padded ramdisk slot does not start with Phase 3 initramfs")
if len(zimage) < 48:
    raise SystemExit("error: zImage is too small")
magic = struct.unpack_from("<I", zimage, 36)[0]
if magic != 0x016F2818:
    raise SystemExit(f"error: zImage magic mismatch: 0x{magic:08x}")
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

printf 'Phase 3 stock-slot no-reset boot candidate verified:\n'
cat "$out_dir/VERIFY-SHA256SUMS"
