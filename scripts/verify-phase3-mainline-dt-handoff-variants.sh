#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

out_dir='build/phase3/dt-handoff-variants'
ramdisk='build/phase3/initramfs/initramfs.cpio'
partition_size=11534336
volume_payload_size=9547776
cmdline='rdinit=/init init=/init root=/dev/ram0 rw panic=20 ignore_loglevel androidboot.hardware=qcom'

test -s "$ramdisk" || fail "missing $ramdisk"

check_variant() {
  slug=$1
  dtb="$out_dir/$slug.dtb"
  zimage_dtb="$out_dir/$slug-zImage-dtb"
  boot_img="$out_dir/$slug-boot.img"
  volume="$out_dir/$slug-volume.bin"
  recovery_img="$out_dir/$slug-recovery.img"

  test -s "$dtb" || fail "missing $dtb"
  test -s "$zimage_dtb" || fail "missing $zimage_dtb"
  test -s "$boot_img" || fail "missing $boot_img"
  test -s "$volume" || fail "missing $volume"
  test -s "$recovery_img" || fail "missing $recovery_img"
  [ "$(wc -c <"$volume")" -eq "$volume_payload_size" ] || fail "$volume size does not match stock recovery volume payload"
  [ "$(wc -c <"$recovery_img")" -eq "$partition_size" ] || fail "$recovery_img size does not match mtd2"
  file "$dtb" | grep 'Device Tree Blob' >/dev/null || fail "$dtb is not a device tree blob"
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

  python3 - "$boot_img" "$ramdisk" "$cmdline" <<'PY'
from pathlib import Path
import struct
import sys

boot_img = Path(sys.argv[1])
expected_ramdisk = Path(sys.argv[2]).read_bytes()
expected_cmdline = sys.argv[3]
data = boot_img.read_bytes()
if len(data) < 608 or data[:8] != b"ANDROID!":
    raise SystemExit(f"error: {boot_img} is not an Android boot image")
kernel_size = struct.unpack_from("<I", data, 8)[0]
ramdisk_size = struct.unpack_from("<I", data, 16)[0]
cmdline = data[64:576].split(b"\0", 1)[0].decode("ascii", "replace")
if cmdline != expected_cmdline:
    raise SystemExit(f"error: {boot_img} cmdline mismatch: {cmdline!r}")

def align(value):
    return ((value + 4095) // 4096) * 4096

offset = align(608) + align(kernel_size)
ramdisk = data[offset : offset + ramdisk_size]
if ramdisk != expected_ramdisk:
    raise SystemExit(f"error: {boot_img} ramdisk does not match Phase 3 cpio")
PY
}

check_variant phase3-dt-msm8660-timer
check_variant phase3-dt-vic-timer

strings "$out_dir/phase3-dt-msm8660-timer.dtb" | grep -F 'qcom,msm-8660-qgic' >/dev/null || fail 'MSM8660 timer DTB lacks qgic compatible'
strings "$out_dir/phase3-dt-msm8660-timer.dtb" | grep -F 'qcom,scss-timer' >/dev/null || fail 'MSM8660 timer DTB lacks scss timer compatible'
strings "$out_dir/phase3-dt-vic-timer.dtb" | grep -F 'arm,versatile-vic' >/dev/null || fail 'VIC timer DTB lacks VIC compatible'
strings "$out_dir/phase3-dt-vic-timer.dtb" | grep -F 'qcom,scss-timer' >/dev/null || fail 'VIC timer DTB lacks scss timer compatible'

sha256sum "$out_dir"/*.dtb "$out_dir"/*-boot.img "$out_dir"/*-recovery.img >"$out_dir/VERIFY-SHA256SUMS"

printf 'Phase 3 DT handoff candidates verified:\n'
cat "$out_dir/VERIFY-SHA256SUMS"
