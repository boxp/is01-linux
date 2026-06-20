#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

stock_recovery=${STOCK_RECOVERY_IMG:-/home/boxp/Documents/obsidian-headless/BOXP/Projects/is01/artifacts/backups/stock-20260618T142509Z/stock-20260618T142509Z/mtd2-recovery.img}
kernel_out=${KERNEL_OUT:-build/phase3/lean-kernel-out}
zimage="$kernel_out/arch/arm/boot/zImage"
ramdisk='build/phase3/initramfs/initramfs.cpio'
out_dir='build/phase3/dt-handoff-variants'
partition_size=11534336
volume_payload_size=9547776
ubinize_args='-m 2048 -s 256 -p 128KiB -O 256'
cmdline='rdinit=/init init=/init root=/dev/ram0 rw panic=20 ignore_loglevel androidboot.hardware=qcom'

test -s "$zimage" || ./scripts/build-phase3-mainline-lean-boot.sh
test -s "$ramdisk" || ./scripts/build-phase3-initramfs.sh
command -v dtc >/dev/null 2>&1 || {
  printf 'error: dtc not found. Install device-tree-compiler.\n' >&2
  exit 1
}
command -v ubinize >/dev/null 2>&1 || {
  printf 'error: ubinize not found. Install mtd-utils.\n' >&2
  exit 1
}

mkdir -p "$out_dir"

if [ -s "$stock_recovery" ]; then
  [ "$(wc -c <"$stock_recovery")" -eq "$partition_size" ] || {
    printf 'error: stock recovery image size does not match mtd2: %s\n' "$stock_recovery" >&2
    exit 1
  }
  image_seq=$(python3 - "$stock_recovery" <<'PY'
from pathlib import Path
import struct
import sys

data = Path(sys.argv[1]).read_bytes()
if len(data) < 64 or struct.unpack_from(">I", data, 0)[0] != 0x55424923:
    raise SystemExit("stock recovery image does not start with a UBI EC header")
print(struct.unpack_from(">I", data, 24)[0])
PY
)
  ubinize_args="$ubinize_args -Q $image_seq"
else
  printf 'warning: stock recovery image not found; building stockless UBI recovery candidates\n' >&2
fi

package_recovery() {
  boot_img=$1
  slug=$2
  ubi_payload="$out_dir/$slug-volume.bin"
  ubi_img="$out_dir/$slug-recovery.ubi"
  recovery_img="$out_dir/$slug-recovery.img"
  ubinize_cfg="$out_dir/$slug-ubinize.cfg"

  python3 - "$boot_img" "$ubi_payload" "$volume_payload_size" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
volume_payload_size = int(sys.argv[3])
data = src.read_bytes()
if len(data) > volume_payload_size:
    raise SystemExit(f"boot image is larger than stock recovery UBI payload area: {len(data)} > {volume_payload_size}")
dst.write_bytes(data + (b"\0" * (volume_payload_size - len(data))))
PY

  cat >"$ubinize_cfg" <<EOF
[boot]
mode=ubi
image=$ubi_payload
vol_id=0
vol_type=dynamic
vol_name=boot
vol_flags=autoresize
EOF

  # shellcheck disable=SC2086
  ubinize -o "$ubi_img" $ubinize_args "$ubinize_cfg"

  python3 - "$ubi_img" "$recovery_img" "$partition_size" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
partition_size = int(sys.argv[3])
data = src.read_bytes()
if len(data) > partition_size:
    raise SystemExit(f"UBI image is larger than recovery partition: {len(data)} > {partition_size}")
dst.write_bytes(data + (b"\xff" * (partition_size - len(data))))
PY
}

build_variant() {
  slug=$1
  dts=$2
  dtb="$out_dir/$slug.dtb"
  zimage_dtb="$out_dir/$slug-zImage-dtb"
  boot_img="$out_dir/$slug-boot.img"

  dtc -I dts -O dtb -o "$dtb" "$dts"
  cat "$zimage" "$dtb" >"$zimage_dtb"

  ./scripts/mkbootimg.py \
    --kernel "$zimage_dtb" \
    --ramdisk "$ramdisk" \
    --output "$boot_img" \
    --kernel-addr 0x20008000 \
    --ramdisk-addr 0x24000000 \
    --second-addr 0x20f00000 \
    --tags-addr 0x20000100 \
    --page-size 2048 \
    --image-align-size 4096 \
    --cmdline "$cmdline" \
    --name phase3dt

  ./scripts/inspect-android-bootimg.py \
    --image-align-size 4096 \
    --expect-page-size 2048 \
    --expect-kernel-addr 0x20008000 \
    --expect-ramdisk-addr 0x24000000 \
    --expect-second-addr 0x20f00000 \
    --expect-tags-addr 0x20000100 \
    "$boot_img" >"$out_dir/$slug-boot-layout.txt"

  package_recovery "$boot_img" "$slug"
}

build_variant \
  phase3-dt-msm8660-timer \
  board/is01/phase3/qcom-qsd8x50-is01-msm8660-timer.dts

build_variant \
  phase3-dt-vic-timer \
  board/is01/phase3/qcom-qsd8x50-is01-vic-timer.dts

sha256sum \
  "$out_dir"/*.dtb \
  "$out_dir"/*-zImage-dtb \
  "$out_dir"/*-boot.img \
  "$out_dir"/*-volume.bin \
  "$out_dir"/*-recovery.img \
  >"$out_dir/SHA256SUMS"

printf 'Phase 3 DT handoff recovery candidates are ready:\n'
cat "$out_dir/SHA256SUMS"
