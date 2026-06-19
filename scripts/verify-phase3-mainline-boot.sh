#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

out_dir='build/phase3/mainline-boot'
boot_img="$out_dir/phase3-mainline-minimal-boot.img"
dtb="$out_dir/qcom-qsd8x50-is01.dtb"
zimage_dtb="$out_dir/zImage-dtb"
ramdisk='build/phase3/initramfs/initramfs.cpio'
extracted_ramdisk="$out_dir/extracted-phase3-initramfs.cpio"

test -s "$boot_img" || fail "missing $boot_img"
test -s "$dtb" || fail "missing $dtb"
test -s "$zimage_dtb" || fail "missing $zimage_dtb"
test -s "$ramdisk" || fail "missing $ramdisk"

file "$boot_img" | grep 'Android bootimg' >/dev/null || fail 'Phase 3 boot payload is not an Android bootimg'
file "$dtb" | grep 'Device Tree Blob' >/dev/null || fail 'Phase 3 DTB is not a device tree blob'

python3 - "$boot_img" "$extracted_ramdisk" <<'PY'
from pathlib import Path
import struct
import sys

boot_img = Path(sys.argv[1])
output = Path(sys.argv[2])
data = boot_img.read_bytes()
if len(data) < 48 or data[:8] != b"ANDROID!":
    raise SystemExit(f"error: {boot_img} is not an Android boot image")
kernel_size = struct.unpack_from("<I", data, 8)[0]
ramdisk_size = struct.unpack_from("<I", data, 16)[0]
cmdline = data[64:576].split(b"\0", 1)[0].decode("ascii", "replace")
if "panic=20" not in cmdline or "rdinit=/init" not in cmdline:
    raise SystemExit(f"error: unexpected Phase 3 cmdline: {cmdline}")

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

cmp "$ramdisk" "$extracted_ramdisk" || fail 'boot image ramdisk does not match Phase 3 cpio'
./scripts/verify-phase3-initramfs.sh

sha256sum "$boot_img" "$dtb" "$zimage_dtb" "$extracted_ramdisk" >"$out_dir/VERIFY-SHA256SUMS"

printf 'Phase 3 mainline boot payload verified:\n'
cat "$out_dir/VERIFY-SHA256SUMS"
