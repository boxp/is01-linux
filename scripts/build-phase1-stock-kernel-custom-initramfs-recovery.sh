#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

stock_recovery=${STOCK_RECOVERY_IMG:-}
if [ -z "$stock_recovery" ]; then
  stock_recovery='/home/boxp/Documents/obsidian-headless/BOXP/Projects/is01/artifacts/backups/stock-20260618T142509Z/stock-20260618T142509Z/mtd2-recovery.img'
fi

out_dir='build/phase1/stock-kernel-custom-initramfs'
stock_boot="$out_dir/stock-recovery-boot.img"
boot_img="$out_dir/phase1-stock-kernel-custom-initramfs-boot.img"
ubi_payload="$out_dir/phase1-stock-kernel-custom-initramfs-volume.bin"
ubi_img="$out_dir/phase1-stock-kernel-custom-initramfs-recovery.ubi"
recovery_img="$out_dir/phase1-stock-kernel-custom-initramfs-recovery.img"
ubinize_cfg="$out_dir/ubinize.cfg"

ramdisk='build/phase1/initramfs/initramfs.cpio.gz'
partition_size=11534336
volume_payload_size=9547776

test -s "$ramdisk" || ./scripts/build-phase1-initramfs.sh
test -s "$stock_recovery" || {
  printf 'error: stock recovery image not found: %s\n' "$stock_recovery" >&2
  printf 'Set STOCK_RECOVERY_IMG=/path/to/mtd2-recovery.img when using a different backup.\n' >&2
  exit 1
}
command -v ubinize >/dev/null 2>&1 || {
  printf 'error: ubinize not found. Install mtd-utils.\n' >&2
  exit 1
}

mkdir -p "$out_dir"

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

./scripts/extract-ubi-volume.py --vol-id 0 --trim-android-bootimg "$stock_recovery" "$stock_boot"
./scripts/repack-android-bootimg.py --source "$stock_boot" --ramdisk "$ramdisk" --output "$boot_img"

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

ubinize -o "$ubi_img" -m 2048 -s 256 -p 128KiB -O 256 -Q "$image_seq" "$ubinize_cfg"

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

file "$stock_boot"
file "$boot_img"
file "$recovery_img"
sha256sum "$stock_boot" "$ramdisk" "$boot_img" "$ubi_payload" "$recovery_img"
