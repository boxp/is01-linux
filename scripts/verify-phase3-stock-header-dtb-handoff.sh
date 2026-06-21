#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

out_dir='build/phase3/stock-header-dtb-handoff'
lean_dir='build/phase3/lean-boot'
kernel_out=${KERNEL_OUT:-build/phase3/lean-kernel-out}
zimage="$kernel_out/arch/arm/boot/zImage"
zimage_dtb="$lean_dir/zImage-dtb"
dtb="$lean_dir/qcom-qsd8x50-is01.dtb"
ramdisk='build/phase3/initramfs/initramfs.cpio'
padded_zimage="$out_dir/phase3-lean-zimage-stock-kernel-slot.bin"
padded_zimage_dtb="$out_dir/phase3-lean-zimage-dtb-stock-kernel-slot.bin"
padded_ramdisk="$out_dir/phase3-initramfs-stock-ramdisk-slot.cpio"
stock_kernel_size=5526688
stock_ramdisk_size=791552
partition_size=11534336

test -s "$zimage" || fail "missing $zimage"
test -s "$zimage_dtb" || fail "missing $zimage_dtb"
test -s "$dtb" || fail "missing $dtb"
test -s "$ramdisk" || fail "missing $ramdisk"
test -s "$padded_zimage" || fail "missing $padded_zimage"
test -s "$padded_zimage_dtb" || fail "missing $padded_zimage_dtb"
test -s "$padded_ramdisk" || fail "missing $padded_ramdisk"

[ "$(wc -c <"$padded_zimage")" -eq "$stock_kernel_size" ] || fail 'padded zImage kernel slot size mismatch'
[ "$(wc -c <"$padded_zimage_dtb")" -eq "$stock_kernel_size" ] || fail 'padded zImage+DTB kernel slot size mismatch'
[ "$(wc -c <"$padded_ramdisk")" -eq "$stock_ramdisk_size" ] || fail 'padded ramdisk slot size mismatch'

python3 - "$zimage" "$zimage_dtb" "$dtb" "$ramdisk" "$padded_zimage" "$padded_zimage_dtb" "$padded_ramdisk" <<'PY'
from pathlib import Path
import sys

zimage = Path(sys.argv[1]).read_bytes()
zimage_dtb = Path(sys.argv[2]).read_bytes()
dtb = Path(sys.argv[3]).read_bytes()
ramdisk = Path(sys.argv[4]).read_bytes()
padded_zimage = Path(sys.argv[5]).read_bytes()
padded_zimage_dtb = Path(sys.argv[6]).read_bytes()
padded_ramdisk = Path(sys.argv[7]).read_bytes()

if not padded_zimage.startswith(zimage):
    raise SystemExit("error: padded zImage slot does not start with zImage")
if padded_zimage.startswith(zimage_dtb):
    raise SystemExit("error: zImage-only slot unexpectedly starts with zImage+DTB")
if not padded_zimage_dtb.startswith(zimage_dtb):
    raise SystemExit("error: padded zImage+DTB slot does not start with zImage+DTB")
if not zimage_dtb.endswith(dtb):
    raise SystemExit("error: zImage+DTB artifact does not end with DTB")
if not padded_ramdisk.startswith(ramdisk):
    raise SystemExit("error: padded ramdisk slot does not start with Phase 3 initramfs")
PY

check_candidate() {
  slug=$1
  expected_second_size=$2
  recovery="$out_dir/$slug-recovery.img"
  boot_img="$out_dir/$slug-boot.img"
  layout="$out_dir/$slug-boot-layout.txt"

  test -s "$recovery" || fail "missing $recovery"
  test -s "$boot_img" || fail "missing $boot_img"
  test -s "$layout" || fail "missing $layout"
  [ "$(wc -c <"$recovery")" -eq "$partition_size" ] || fail "$recovery size is not recovery partition size"

  ./scripts/inspect-android-bootimg.py \
    --image-align-size 4096 \
    --expect-page-size 2048 \
    --expect-align-size 4096 \
    --expect-kernel-addr 0x20008000 \
    --expect-ramdisk-addr 0x24000000 \
    --expect-second-addr 0x20f00000 \
    --expect-tags-addr 0x20000100 \
    --expect-cmdline-contains 'rdinit=/init' \
    --expect-cmdline-contains 'panic=20' \
    "$boot_img" >"$out_dir/$slug-VERIFY-BOOT-LAYOUT.txt"

  python3 - "$boot_img" "$expected_second_size" "$stock_kernel_size" "$stock_ramdisk_size" <<'PY'
from pathlib import Path
import struct
import sys

boot_img = Path(sys.argv[1])
expected_second_size = int(sys.argv[2])
expected_kernel_size = int(sys.argv[3])
expected_ramdisk_size = int(sys.argv[4])
data = boot_img.read_bytes()
if data[:8] != b"ANDROID!":
    raise SystemExit(f"error: {boot_img} is not an Android boot image")
kernel_size = struct.unpack_from("<I", data, 8)[0]
ramdisk_size = struct.unpack_from("<I", data, 16)[0]
second_size = struct.unpack_from("<I", data, 24)[0]
if kernel_size != expected_kernel_size:
    raise SystemExit(f"error: {boot_img} kernel_size {kernel_size} != {expected_kernel_size}")
if ramdisk_size != expected_ramdisk_size:
    raise SystemExit(f"error: {boot_img} ramdisk_size {ramdisk_size} != {expected_ramdisk_size}")
if second_size != expected_second_size:
    raise SystemExit(f"error: {boot_img} second_size {second_size} != {expected_second_size}")
PY
}

dtb_size=$(wc -c <"$dtb")
check_candidate phase3-stockslot-zimage-only-phase3-cmdline 0
check_candidate phase3-stockslot-zimage-second-dtb-phase3-cmdline "$dtb_size"
check_candidate phase3-stockslot-zimage-appended-second-dtb-phase3-cmdline "$dtb_size"

./scripts/verify-phase3-initramfs.sh

sha256sum \
  "$out_dir"/*-boot.img \
  "$out_dir"/*-recovery.img \
  >"$out_dir/VERIFY-SHA256SUMS"

printf 'Phase 3 stock-header DTB handoff candidates verified:\n'
cat "$out_dir/VERIFY-SHA256SUMS"
