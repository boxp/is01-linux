#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

out_dir='build/phase2/recovery'
boot_img="$out_dir/phase2-stock-kernel-userspace-boot.img"
ubi_payload="$out_dir/phase2-stock-kernel-userspace-volume.bin"
raw_ramdisk="$out_dir/phase2-userspace-initramfs.img"
recovery_img="$out_dir/phase2-stock-kernel-userspace-recovery.img"
extracted_ramdisk="$out_dir/extracted-phase2-userspace-initramfs.img"
roundtrip_boot="$out_dir/roundtrip-phase2-stock-kernel-userspace-boot.img"
expected_cpio='build/phase2/initramfs/initramfs.cpio'
partition_size=11534336

test -s "$boot_img" || fail "missing $boot_img"
test -s "$ubi_payload" || fail "missing $ubi_payload"
test -s "$raw_ramdisk" || fail "missing $raw_ramdisk"
test -s "$recovery_img" || fail "missing $recovery_img"
test -s "$expected_cpio" || fail "missing $expected_cpio"

file "$boot_img" | grep 'Android bootimg' >/dev/null || fail 'Phase 2 boot image is not an Android bootimg'
file "$recovery_img" | grep 'UBI image' >/dev/null || fail 'Phase 2 recovery image is not a UBI image'
[ "$(wc -c <"$ubi_payload")" -eq 9547776 ] || fail 'UBI volume payload size does not match stock recovery'
[ "$(wc -c <"$recovery_img")" -eq "$partition_size" ] || fail 'recovery image size does not match mtd2'
./scripts/check-ubi-layout.py --expect-vid-offset 256 --expect-data-offset 2048 --expect-pebs 76 "$recovery_img"

./scripts/extract-ubi-volume.py --vol-id 0 --trim-android-bootimg --android-bootimg-align-size 4096 "$recovery_img" "$roundtrip_boot"
cmp "$boot_img" "$roundtrip_boot" || fail 'repacked UBI volume does not round-trip to Phase 2 boot image'

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

def align(value):
    return ((value + 4095) // 4096) * 4096

offset = align(608) + align(kernel_size)
ramdisk = data[offset : offset + ramdisk_size]
if len(ramdisk) != ramdisk_size:
    raise SystemExit(f"error: {boot_img} ramdisk is truncated")
if not ramdisk.startswith(b"070701"):
    raise SystemExit(f"error: {boot_img} 4096-aligned ramdisk does not start with newc cpio magic")
output.write_bytes(ramdisk)
PY
cmp "$raw_ramdisk" "$extracted_ramdisk" || fail 'boot image ramdisk does not match raw Phase 2 initramfs'
cmp "$expected_cpio" "$extracted_ramdisk" || fail 'boot image ramdisk payload does not match Phase 2 cpio'
./scripts/verify-phase2-initramfs.sh

sha256sum "$boot_img" "$ubi_payload" "$recovery_img" "$roundtrip_boot" "$extracted_ramdisk" >"$out_dir/SHA256SUMS"

printf 'Phase 2 recovery artifacts verified:\n'
cat "$out_dir/SHA256SUMS"
