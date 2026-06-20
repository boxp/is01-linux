#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

probe_dir='build/phase3/boot-entry-probes'
ramdisk='build/phase3/initramfs/initramfs.cpio'
partition_size=11534336
volume_payload_size=9547776

test -s "$ramdisk" || fail "missing $ramdisk"

check_probe() {
  slug=$1
  align_size=$2
  expected_cmdline=$3
  boot_img="$probe_dir/$slug-boot.img"
  volume="$probe_dir/$slug-volume.bin"
  recovery_img="$probe_dir/$slug-recovery.img"

  test -s "$boot_img" || fail "missing $boot_img"
  test -s "$volume" || fail "missing $volume"
  test -s "$recovery_img" || fail "missing $recovery_img"
  [ "$(wc -c <"$volume")" -eq "$volume_payload_size" ] || fail "$volume size does not match stock recovery volume payload"
  [ "$(wc -c <"$recovery_img")" -eq "$partition_size" ] || fail "$recovery_img size does not match mtd2"
  file "$boot_img" | grep 'Android bootimg' >/dev/null || fail "$boot_img is not an Android bootimg"
  file "$recovery_img" | grep 'UBI image' >/dev/null || fail "$recovery_img is not a UBI image"

  ./scripts/inspect-android-bootimg.py \
    --image-align-size "$align_size" \
    --expect-page-size 2048 \
    --expect-align-size "$align_size" \
    --expect-kernel-addr 0x20008000 \
    --expect-ramdisk-addr 0x24000000 \
    --expect-second-addr 0x20f00000 \
    --expect-tags-addr 0x20000100 \
    "$boot_img" >/dev/null

  python3 - "$boot_img" "$ramdisk" "$align_size" "$expected_cmdline" <<'PY'
from pathlib import Path
import struct
import sys

boot_img = Path(sys.argv[1])
expected_ramdisk = Path(sys.argv[2]).read_bytes()
align_size = int(sys.argv[3])
expected_cmdline = sys.argv[4]
data = boot_img.read_bytes()
if len(data) < 608 or data[:8] != b"ANDROID!":
    raise SystemExit(f"error: {boot_img} is not an Android boot image")
kernel_size = struct.unpack_from("<I", data, 8)[0]
ramdisk_size = struct.unpack_from("<I", data, 16)[0]
cmdline = data[64:576].split(b"\0", 1)[0].decode("ascii", "replace")
if cmdline != expected_cmdline:
    raise SystemExit(f"error: {boot_img} cmdline mismatch: {cmdline!r}")

def align(value):
    return ((value + align_size - 1) // align_size) * align_size

offset = align(608) + align(kernel_size)
ramdisk = data[offset : offset + ramdisk_size]
if ramdisk != expected_ramdisk:
    raise SystemExit(f"error: {boot_img} ramdisk does not match Phase 3 cpio")
PY
}

check_probe \
  phase3-probe-4096-mainline-cmdline \
  4096 \
  'rdinit=/init init=/init root=/dev/ram0 rw panic=20 ignore_loglevel androidboot.hardware=qcom'

check_probe \
  phase3-probe-4096-stock-cmdline \
  4096 \
  'console=ttyMSM2,115200n8 androidboot.hardware=qcom'

check_probe \
  phase3-probe-4096-empty-cmdline \
  4096 \
  ''

check_probe \
  phase3-probe-2048-mainline-cmdline \
  2048 \
  'rdinit=/init init=/init root=/dev/ram0 rw panic=20 ignore_loglevel androidboot.hardware=qcom'

sha256sum "$probe_dir"/*-boot.img "$probe_dir"/*-recovery.img >"$probe_dir/VERIFY-SHA256SUMS"

printf 'Phase 3 boot-entry probe candidates verified:\n'
cat "$probe_dir/VERIFY-SHA256SUMS"
