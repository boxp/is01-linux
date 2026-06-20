#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

out_dir='build/phase3/early-payload-probes'
partition_size=11534336
volume_payload_size=9547776
cmdline='is01_phase3_early_payload_probe'
ramdisk="$out_dir/empty-ramdisk.img"

test -f "$ramdisk" || fail "missing $ramdisk"
[ "$(wc -c <"$ramdisk")" -eq 0 ] || fail "$ramdisk must be empty"

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

check_probe phase3-early-loop payloads/phase3/early-loop.S
check_probe phase3-early-fb-fill payloads/phase3/early-fb-fill.S

grep -F '0x02b00000' payloads/phase3/early-fb-fill.S >/dev/null || fail 'fb-fill payload lost Deckard framebuffer base'
grep -F '0x001c2000' payloads/phase3/early-fb-fill.S >/dev/null || fail 'fb-fill payload lost Deckard framebuffer size'

sha256sum "$out_dir"/*.bin "$out_dir"/*-boot.img "$out_dir"/*-recovery.img >"$out_dir/VERIFY-SHA256SUMS"

printf 'Phase 3 early payload candidates verified:\n'
cat "$out_dir/VERIFY-SHA256SUMS"
