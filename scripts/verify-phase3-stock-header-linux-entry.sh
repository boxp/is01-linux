#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

out_dir='build/phase3/stock-header-linux-entry'
partition_size=11534336
volume_payload_size=9547776
stock_kernel_size=5526688
stock_ramdisk_size=791552
stock_cmdline='console=ttyMSM2,115200n8 androidboot.hardware=qcom'
phase3_cmdline='rdinit=/init init=/init root=/dev/ram0 rw panic=20 ignore_loglevel androidboot.hardware=qcom'
zimage_dtb='build/phase3/lean-boot/zImage-dtb'
ramdisk='build/phase3/initramfs/initramfs.cpio'
padded_kernel="$out_dir/phase3-lean-zimage-dtb-stock-kernel-slot.bin"
padded_ramdisk="$out_dir/phase3-initramfs-stock-ramdisk-slot.cpio"

test -s "$out_dir/source-stock-compatible-boot.img" || fail 'missing source stock-compatible boot image'
test -s "$out_dir/source-stock-compatible-boot.txt" || fail 'missing source note'
test -s "$zimage_dtb" || fail "missing $zimage_dtb"
test -s "$ramdisk" || fail "missing $ramdisk"
test -s "$padded_kernel" || fail "missing $padded_kernel"
test -s "$padded_ramdisk" || fail "missing $padded_ramdisk"
[ "$(wc -c <"$padded_kernel")" -eq "$stock_kernel_size" ] || fail 'padded kernel does not match stock kernel slot size'
[ "$(wc -c <"$padded_ramdisk")" -eq "$stock_ramdisk_size" ] || fail 'padded ramdisk does not match stock ramdisk slot size'

python3 - "$zimage_dtb" "$ramdisk" "$padded_kernel" "$padded_ramdisk" <<'PY'
from pathlib import Path
import sys

kernel = Path(sys.argv[1]).read_bytes()
ramdisk = Path(sys.argv[2]).read_bytes()
padded_kernel = Path(sys.argv[3]).read_bytes()
padded_ramdisk = Path(sys.argv[4]).read_bytes()
if not padded_kernel.startswith(kernel):
    raise SystemExit("error: padded kernel does not start with lean zImage+DTB")
if padded_kernel[len(kernel):] != b"\0" * (len(padded_kernel) - len(kernel)):
    raise SystemExit("error: padded kernel tail is not zero-filled")
if not padded_ramdisk.startswith(ramdisk):
    raise SystemExit("error: padded ramdisk does not start with Phase 3 initramfs")
if padded_ramdisk[len(ramdisk):] != b"\0" * (len(padded_ramdisk) - len(ramdisk)):
    raise SystemExit("error: padded ramdisk tail is not zero-filled")
PY

check_candidate() {
  slug=$1
  expected_cmdline=$2
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
    --expect-cmdline-contains "$expected_cmdline" \
    "$boot_img" >/dev/null

  python3 - "$boot_img" "$padded_kernel" "$padded_ramdisk" <<'PY'
from pathlib import Path
import struct
import sys

boot_img = Path(sys.argv[1])
expected_kernel = Path(sys.argv[2]).read_bytes()
expected_ramdisk = Path(sys.argv[3]).read_bytes()
data = boot_img.read_bytes()
if len(data) < 608 or data[:8] != b"ANDROID!":
    raise SystemExit(f"error: {boot_img} is not an Android boot image")
kernel_size = struct.unpack_from("<I", data, 8)[0]
ramdisk_size = struct.unpack_from("<I", data, 16)[0]
second_size = struct.unpack_from("<I", data, 24)[0]
if kernel_size != len(expected_kernel):
    raise SystemExit(f"error: kernel size mismatch: {kernel_size} != {len(expected_kernel)}")
if ramdisk_size != len(expected_ramdisk):
    raise SystemExit(f"error: ramdisk size mismatch: {ramdisk_size} != {len(expected_ramdisk)}")
if second_size != 0:
    raise SystemExit("error: second payload must be empty")

def align(value):
    return ((value + 4095) // 4096) * 4096

kernel_offset = align(608)
ramdisk_offset = kernel_offset + align(kernel_size)
kernel = data[kernel_offset : kernel_offset + kernel_size]
ramdisk = data[ramdisk_offset : ramdisk_offset + ramdisk_size]
if kernel != expected_kernel:
    raise SystemExit("error: kernel slot mismatch")
if ramdisk != expected_ramdisk:
    raise SystemExit("error: ramdisk slot mismatch")
PY
}

check_candidate phase3-stockslot-lean-stock-cmdline "$stock_cmdline"
check_candidate phase3-stockslot-lean-phase3-cmdline 'rdinit=/init'

./scripts/verify-phase3-initramfs.sh

sha256sum "$out_dir"/*-boot.img "$out_dir"/*-recovery.img >"$out_dir/VERIFY-SHA256SUMS"

printf 'Phase 3 stock-header Linux entry candidates verified:\n'
cat "$out_dir/VERIFY-SHA256SUMS"
