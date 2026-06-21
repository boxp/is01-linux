#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

out_dir='build/phase3/stock-header-kernel-swap-probes'
partition_size=11534336
volume_payload_size=9547776
stock_kernel_size=5526688
stock_ramdisk_size=791552
stock_cmdline='console=ttyMSM2,115200n8 androidboot.hardware=qcom'

test -s "$out_dir/source-stock-compatible-boot.img" || fail 'missing source stock-compatible boot image'
test -s "$out_dir/source-stock-compatible-boot.txt" || fail 'missing source note'

check_boot_payload() {
  boot_img=$1
  expected_kernel=$2
  python3 - "$boot_img" "$expected_kernel" "$stock_kernel_size" "$stock_ramdisk_size" "$stock_cmdline" <<'PY'
from pathlib import Path
import struct
import sys

boot_img = Path(sys.argv[1])
expected_kernel = Path(sys.argv[2]).read_bytes()
stock_kernel_size = int(sys.argv[3])
stock_ramdisk_size = int(sys.argv[4])
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
if kernel_size != stock_kernel_size:
    raise SystemExit(f"error: {boot_img} kernel_size mismatch: {kernel_size} != {stock_kernel_size}")
if ramdisk_size != stock_ramdisk_size:
    raise SystemExit(f"error: {boot_img} ramdisk_size mismatch: {ramdisk_size} != {stock_ramdisk_size}")
if second_size != 0:
    raise SystemExit(f"error: {boot_img} second payload must be empty")
if len(expected_kernel) != stock_kernel_size:
    raise SystemExit(f"error: expected kernel slot size mismatch: {len(expected_kernel)} != {stock_kernel_size}")

def align(value):
    return ((value + align_size - 1) // align_size) * align_size

kernel_offset = align(608)
kernel = data[kernel_offset : kernel_offset + kernel_size]
if kernel != expected_kernel:
    raise SystemExit(f"error: {boot_img} kernel slot payload mismatch")
PY
}

check_probe() {
  slug=$1
  source=$2
  elf="$out_dir/$slug.elf"
  payload="$out_dir/$slug.bin"
  padded_kernel="$out_dir/$slug-stock-kernel-slot.bin"
  boot_img="$out_dir/$slug-boot.img"
  volume="$out_dir/$slug-volume.bin"
  recovery_img="$out_dir/$slug-recovery.img"

  test -s "$source" || fail "missing $source"
  test -s "$elf" || fail "missing $elf"
  test -s "$payload" || fail "missing $payload"
  test -s "$padded_kernel" || fail "missing $padded_kernel"
  test -s "$boot_img" || fail "missing $boot_img"
  test -s "$volume" || fail "missing $volume"
  test -s "$recovery_img" || fail "missing $recovery_img"
  [ "$(wc -c <"$padded_kernel")" -eq "$stock_kernel_size" ] || fail "$padded_kernel does not match stock kernel slot size"
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
    --expect-cmdline-contains "$stock_cmdline" \
    "$boot_img" >/dev/null

  check_boot_payload "$boot_img" "$padded_kernel"
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
if end - start > len(data):
    raise SystemExit(f"error: {path} zImage end exceeds payload length")
PY
}

check_probe phase3-stockslot-proc-comm-reset payloads/phase3/proc-comm-reset.S
check_probe phase3-stockslot-zimage-proc-comm-reset payloads/phase3/zimage-proc-comm-reset.S
check_probe phase3-stockslot-control-loop payloads/phase3/early-loop.S

check_zimage_header "$out_dir/phase3-stockslot-zimage-proc-comm-reset.bin"
grep -F '0x00100000' payloads/phase3/proc-comm-reset.S >/dev/null || fail 'proc_comm reset payload lost shared RAM base'
grep -F '0xAC100000' payloads/phase3/proc-comm-reset.S >/dev/null || fail 'proc_comm reset payload lost MSM CSR base'
grep -F '0x0000002A' payloads/phase3/proc-comm-reset.S >/dev/null || fail 'proc_comm reset payload lost PCOM_RESET_CHIP_IMM command'
grep -F '0x00000418' payloads/phase3/proc-comm-reset.S >/dev/null || fail 'proc_comm reset payload lost A2M interrupt offset'

sha256sum "$out_dir"/*.bin "$out_dir"/*-boot.img "$out_dir"/*-recovery.img >"$out_dir/VERIFY-SHA256SUMS"

printf 'Phase 3 stock-header kernel-swap candidates verified:\n'
cat "$out_dir/VERIFY-SHA256SUMS"
