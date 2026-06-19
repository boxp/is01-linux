#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

stock_recovery=${STOCK_RECOVERY_IMG:-}
if [ -z "$stock_recovery" ]; then
  stock_recovery='/home/boxp/Documents/obsidian-headless/BOXP/Projects/is01/artifacts/backups/stock-20260618T142509Z/stock-20260618T142509Z/mtd2-recovery.img'
fi

out_dir='build/phase1/repack-stock'
stock_boot="$out_dir/stock-recovery-boot.img"
ubi_img="$out_dir/phase1-stock-repack-recovery.ubi"
recovery_img="$out_dir/phase1-stock-repack-recovery.img"
ubinize_cfg="$out_dir/ubinize.cfg"
partition_size=11534336

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
file "$stock_boot" | grep 'Android bootimg' >/dev/null || {
  file "$stock_boot" >&2
  printf 'error: extracted stock recovery volume is not an Android bootimg\n' >&2
  exit 1
}

cat >"$ubinize_cfg" <<EOF
[boot]
mode=ubi
image=$stock_boot
vol_id=0
vol_type=dynamic
vol_name=boot
vol_flags=autoresize
EOF

ubinize -o "$ubi_img" -m 256 -p 128KiB -O 256 -Q "$image_seq" "$ubinize_cfg"

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

file "$stock_recovery"
file "$stock_boot"
file "$recovery_img"
sha256sum "$stock_recovery" "$stock_boot" "$recovery_img"
