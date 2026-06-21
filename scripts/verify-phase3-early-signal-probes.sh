#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

out_dir='build/phase3/early-signal-probes'
partition_size=11534336
volume_payload_size=9547776
cmdline='console=ttyDCC0 androidboot.hardware=qcom'
ramdisk="$out_dir/empty-ramdisk.img"

test -f "$ramdisk" || fail "missing $ramdisk"
[ "$(wc -c <"$ramdisk")" -eq 0 ] || fail "$ramdisk must be empty"

check_boot_payload() {
  boot_img=$1
  payload=$2
  python3 - "$boot_img" "$payload" "$cmdline" <<'PY'
from pathlib import Path
import struct
import sys

boot_img = Path(sys.argv[1])
expected_kernel = Path(sys.argv[2]).read_bytes()
expected_cmdline = sys.argv[3]
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
if ramdisk_size != 0:
    raise SystemExit(f"error: {boot_img} ramdisk must be empty")
if second_size != 0:
    raise SystemExit(f"error: {boot_img} second payload must be empty")

def align(value):
    return ((value + align_size - 1) // align_size) * align_size

kernel_offset = align(608)
kernel = data[kernel_offset : kernel_offset + kernel_size]
if kernel != expected_kernel:
    raise SystemExit(f"error: {boot_img} kernel payload mismatch")
PY
}

check_probe() {
  slug=$1
  expected_source=$2
  elf="$out_dir/$slug.elf"
  payload="$out_dir/$slug.bin"
  boot_img="$out_dir/$slug-boot.img"
  volume="$out_dir/$slug-volume.bin"
  recovery_img="$out_dir/$slug-recovery.img"

  test -s "$expected_source" || fail "missing $expected_source"
  test -s "$elf" || fail "missing $elf"
  test -s "$payload" || fail "missing $payload"
  test -s "$boot_img" || fail "missing $boot_img"
  test -s "$volume" || fail "missing $volume"
  test -s "$recovery_img" || fail "missing $recovery_img"
  [ "$(wc -c <"$volume")" -eq "$volume_payload_size" ] || fail "$volume size does not match stock recovery volume payload"
  [ "$(wc -c <"$recovery_img")" -eq "$partition_size" ] || fail "$recovery_img size does not match mtd2"
  file "$elf" | grep -E 'ELF 32-bit.*ARM' >/dev/null || fail "$elf is not a 32-bit ARM ELF"
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

  check_boot_payload "$boot_img" "$payload"
}

check_zimage_header() {
  payload=$1
  python3 - "$payload" <<'PY'
from pathlib import Path
import struct
import sys

path = Path(sys.argv[1])
data = path.read_bytes()
if len(data) < 0x30:
    raise SystemExit(f"error: {path} is too small for a zImage magic header")
magic, start, end = struct.unpack_from("<III", data, 0x24)
if magic != 0x016F2818:
    raise SystemExit(f"error: {path} zImage magic mismatch: 0x{magic:08x}")
if start != 0x20008000:
    raise SystemExit(f"error: {path} zImage start mismatch: 0x{start:08x}")
if end <= start:
    raise SystemExit(f"error: {path} zImage end is not after start: 0x{end:08x}")
if end - start != len(data):
    raise SystemExit(f"error: {path} zImage end does not match binary length: 0x{end:08x} vs {len(data)}")
PY
}

check_probe phase3-image-fb-fill payloads/phase3/early-fb-fill.S
check_probe phase3-zimage-fb-fill payloads/phase3/zimage-fb-fill.S
check_probe phase3-image-loop payloads/phase3/early-loop.S

check_zimage_header "$out_dir/phase3-zimage-fb-fill.bin"
grep -F '0x02b00000' payloads/phase3/zimage-fb-fill.S >/dev/null || fail 'zImage fb-fill payload lost Deckard framebuffer base'
grep -F '0x001c2000' payloads/phase3/zimage-fb-fill.S >/dev/null || fail 'zImage fb-fill payload lost Deckard framebuffer size'

sha256sum "$out_dir"/*.bin "$out_dir"/*-boot.img "$out_dir"/*-recovery.img >"$out_dir/VERIFY-SHA256SUMS"

printf 'Phase 3 Image/zImage-shaped early signal candidates verified:\n'
cat "$out_dir/VERIFY-SHA256SUMS"
