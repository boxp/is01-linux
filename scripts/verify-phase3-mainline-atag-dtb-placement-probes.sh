#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

kernel_out=${KERNEL_OUT:-build/phase3/lean-kernel-out}
zimage="$kernel_out/arch/arm/boot/zImage"
payload_dir='build/phase3/lean-boot'
dtb="$payload_dir/qcom-qsd8x50-is01.dtb"
zimage_dtb="$payload_dir/zImage-dtb"
ramdisk='build/phase3/initramfs/initramfs.cpio'
out_dir='build/phase3/atag-dtb-placement-probes'
partition_size=11534336
volume_payload_size=9547776
cmdline='rdinit=/init init=/init root=/dev/ram0 rw panic=20 ignore_loglevel androidboot.hardware=qcom'

test -s "$zimage" || fail "missing $zimage"
test -s "$dtb" || fail "missing $dtb"
test -s "$zimage_dtb" || fail "missing $zimage_dtb"
test -s "$ramdisk" || fail "missing $ramdisk"

check_probe() {
  slug=$1
  expected_kernel=$2
  expected_second=$3
  boot_img="$out_dir/$slug-boot.img"
  volume="$out_dir/$slug-volume.bin"
  recovery_img="$out_dir/$slug-recovery.img"

  test -s "$boot_img" || fail "missing $boot_img"
  test -s "$volume" || fail "missing $volume"
  test -s "$recovery_img" || fail "missing $recovery_img"
  [ "$(wc -c <"$volume")" -eq "$volume_payload_size" ] || fail "$volume size does not match stock recovery volume payload"
  [ "$(wc -c <"$recovery_img")" -eq "$partition_size" ] || fail "$recovery_img size does not match mtd2"
  file "$boot_img" | grep 'Android bootimg' >/dev/null || fail "$boot_img is not an Android bootimg"
  file "$recovery_img" | grep 'UBI image' >/dev/null || fail "$recovery_img is not a UBI image"

  ./scripts/inspect-android-bootimg.py \
    --image-align-size 4096 \
    --expect-page-size 2048 \
    --expect-align-size 4096 \
    --expect-kernel-addr 0x20008000 \
    --expect-ramdisk-addr 0x24000000 \
    --expect-second-addr 0x20f00000 \
    --expect-tags-addr 0x20000100 \
    "$boot_img" >/dev/null

  python3 - "$boot_img" "$expected_kernel" "$ramdisk" "$expected_second" "$cmdline" <<'PY'
from pathlib import Path
import struct
import sys

boot_img = Path(sys.argv[1])
expected_kernel = Path(sys.argv[2]).read_bytes()
expected_ramdisk = Path(sys.argv[3]).read_bytes()
expected_second_arg = sys.argv[4]
expected_second = b"" if expected_second_arg == "-" else Path(expected_second_arg).read_bytes()
expected_cmdline = sys.argv[5]
align_size = 4096
data = boot_img.read_bytes()
if len(data) < 608 or data[:8] != b"ANDROID!":
    raise SystemExit(f"error: {boot_img} is not an Android boot image")
kernel_size = struct.unpack_from("<I", data, 8)[0]
ramdisk_size = struct.unpack_from("<I", data, 16)[0]
second_size = struct.unpack_from("<I", data, 24)[0]
cmdline = data[64:576].split(b"\0", 1)[0].decode("ascii", "replace")
if cmdline != expected_cmdline:
    raise SystemExit(f"error: {boot_img} cmdline mismatch: {cmdline!r}")
if kernel_size != len(expected_kernel):
    raise SystemExit(f"error: {boot_img} kernel size mismatch")
if ramdisk_size != len(expected_ramdisk):
    raise SystemExit(f"error: {boot_img} ramdisk size mismatch")
if second_size != len(expected_second):
    raise SystemExit(f"error: {boot_img} second size mismatch")

def align(value):
    return ((value + align_size - 1) // align_size) * align_size

kernel_offset = align(608)
ramdisk_offset = kernel_offset + align(kernel_size)
second_offset = ramdisk_offset + align(ramdisk_size)
kernel = data[kernel_offset : kernel_offset + kernel_size]
ramdisk = data[ramdisk_offset : ramdisk_offset + ramdisk_size]
second = data[second_offset : second_offset + second_size]
if kernel != expected_kernel:
    raise SystemExit(f"error: {boot_img} kernel payload mismatch")
if ramdisk != expected_ramdisk:
    raise SystemExit(f"error: {boot_img} ramdisk does not match Phase 3 cpio")
if second != expected_second:
    raise SystemExit(f"error: {boot_img} second payload mismatch")
PY
}

check_probe phase3-atag-only-zimage "$zimage" -
check_probe phase3-dtb-in-second "$zimage" "$dtb"
check_probe phase3-appended-dtb-second-duplicate "$zimage_dtb" "$dtb"

sha256sum "$out_dir"/*-boot.img "$out_dir"/*-recovery.img >"$out_dir/VERIFY-SHA256SUMS"

printf 'Phase 3 ATAG/DTB placement candidates verified:\n'
cat "$out_dir/VERIFY-SHA256SUMS"
