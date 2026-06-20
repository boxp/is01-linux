#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

out_dir='build/phase3/lean-boot'
boot_img="$out_dir/phase3-mainline-lean-boot.img"
dtb="$out_dir/qcom-qsd8x50-is01.dtb"
zimage_dtb="$out_dir/zImage-dtb"
ramdisk='build/phase3/initramfs/initramfs.cpio'
baseline_boot='build/phase3/mainline-boot/phase3-mainline-minimal-boot.img'
extracted_ramdisk="$out_dir/extracted-phase3-initramfs.cpio"

test -s "$boot_img" || fail "missing $boot_img"
test -s "$dtb" || fail "missing $dtb"
test -s "$zimage_dtb" || fail "missing $zimage_dtb"
test -s "$ramdisk" || fail "missing $ramdisk"

file "$boot_img" | grep 'Android bootimg' >/dev/null || fail 'Phase 3 lean boot payload is not an Android bootimg'
file "$dtb" | grep 'Device Tree Blob' >/dev/null || fail 'Phase 3 lean DTB is not a device tree blob'

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

python3 - "$boot_img" "$extracted_ramdisk" <<'PY'
from pathlib import Path
import struct
import sys

boot_img = Path(sys.argv[1])
output = Path(sys.argv[2])
data = boot_img.read_bytes()
if len(data) < 608 or data[:8] != b"ANDROID!":
    raise SystemExit(f"error: {boot_img} is not an Android boot image")
kernel_size = struct.unpack_from("<I", data, 8)[0]
ramdisk_size = struct.unpack_from("<I", data, 16)[0]

def align(value):
    return ((value + 4095) // 4096) * 4096

offset = align(608) + align(kernel_size)
ramdisk = data[offset : offset + ramdisk_size]
if len(ramdisk) != ramdisk_size:
    raise SystemExit(f"error: {boot_img} ramdisk is truncated")
if not ramdisk.startswith(b"070701"):
    raise SystemExit(f"error: {boot_img} ramdisk does not start with newc cpio magic")
output.write_bytes(ramdisk)
PY

cmp "$ramdisk" "$extracted_ramdisk" || fail 'lean boot image ramdisk does not match Phase 3 cpio'

if [ -s "$baseline_boot" ]; then
  lean_size=$(wc -c <"$boot_img")
  baseline_size=$(wc -c <"$baseline_boot")
  [ "$lean_size" -lt "$baseline_size" ] || fail "lean boot image is not smaller than baseline: $lean_size >= $baseline_size"
fi

./scripts/verify-phase3-initramfs.sh

sha256sum "$boot_img" "$dtb" "$zimage_dtb" "$extracted_ramdisk" >"$out_dir/VERIFY-SHA256SUMS"

printf 'Phase 3 lean mainline boot payload verified:\n'
cat "$out_dir/VERIFY-SHA256SUMS"
