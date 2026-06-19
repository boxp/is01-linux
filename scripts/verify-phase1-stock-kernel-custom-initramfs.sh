#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

out_dir='build/phase1/stock-kernel-custom-initramfs'
boot_img="$out_dir/phase1-stock-kernel-custom-initramfs-boot.img"
ubi_payload="$out_dir/phase1-stock-kernel-custom-initramfs-volume.bin"
recovery_img="$out_dir/phase1-stock-kernel-custom-initramfs-recovery.img"
extracted_ramdisk="$out_dir/extracted-phase1-stock-kernel-custom-initramfs-ramdisk.cpio.gz"
roundtrip_boot="$out_dir/roundtrip-phase1-stock-kernel-custom-initramfs-boot.img"
expected_ramdisk='build/phase1/initramfs/initramfs.cpio.gz'
partition_size=11534336

test -s "$boot_img" || fail "missing $boot_img"
test -s "$ubi_payload" || fail "missing $ubi_payload"
test -s "$recovery_img" || fail "missing $recovery_img"
test -s "$expected_ramdisk" || fail "missing $expected_ramdisk"

file "$boot_img" | grep 'Android bootimg' >/dev/null || fail 'stock-kernel custom-initramfs boot image is not an Android bootimg'
file "$recovery_img" | grep 'UBI image' >/dev/null || fail 'stock-kernel custom-initramfs recovery image is not a UBI image'
[ "$(wc -c <"$ubi_payload")" -eq 9547776 ] || fail 'UBI volume payload size does not match stock recovery'
[ "$(wc -c <"$recovery_img")" -eq "$partition_size" ] || fail 'recovery image size does not match mtd2'
./scripts/check-ubi-layout.py --expect-vid-offset 256 --expect-data-offset 2048 --expect-pebs 76 "$recovery_img"

./scripts/extract-ubi-volume.py --vol-id 0 --trim-android-bootimg "$recovery_img" "$roundtrip_boot"
cmp "$boot_img" "$roundtrip_boot" || fail 'repacked UBI volume does not round-trip to stock-kernel custom-initramfs boot image'

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
page_size = struct.unpack_from("<I", data, 36)[0]
if page_size == 0:
    raise SystemExit(f"error: {boot_img} has page_size=0")

def align(value):
    return ((value + page_size - 1) // page_size) * page_size

offset = page_size + align(kernel_size)
ramdisk = data[offset : offset + ramdisk_size]
if len(ramdisk) != ramdisk_size:
    raise SystemExit(f"error: {boot_img} ramdisk is truncated")
output.write_bytes(ramdisk)
PY
cmp "$expected_ramdisk" "$extracted_ramdisk" || fail 'boot image ramdisk does not match Phase 1 initramfs'

sha256sum "$boot_img" "$ubi_payload" "$recovery_img" "$roundtrip_boot" "$extracted_ramdisk" >"$out_dir/SHA256SUMS"

printf 'Phase 1 stock-kernel custom-initramfs artifacts verified:\n'
cat "$out_dir/SHA256SUMS"
