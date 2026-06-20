#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

stock_recovery=${STOCK_RECOVERY_IMG:-/home/boxp/Documents/obsidian-headless/BOXP/Projects/is01/artifacts/backups/stock-20260618T142509Z/stock-20260618T142509Z/mtd2-recovery.img}

payload_dir='build/phase3/lean-boot'
boot_payload="$payload_dir/phase3-mainline-lean-boot.img"
out_dir='build/phase3/lean-recovery'
boot_img="$out_dir/phase3-mainline-lean-boot.img"
ubi_payload="$out_dir/phase3-mainline-lean-volume.bin"
ubi_img="$out_dir/phase3-mainline-lean-recovery.ubi"
recovery_img="$out_dir/phase3-mainline-lean-recovery.img"
ubinize_cfg="$out_dir/ubinize.cfg"
partition_size=11534336
volume_payload_size=9547776

test -s "$boot_payload" || ./scripts/build-phase3-mainline-lean-boot.sh
command -v ubinize >/dev/null 2>&1 || {
  printf 'error: ubinize not found. Install mtd-utils.\n' >&2
  exit 1
}

mkdir -p "$out_dir"

ubinize_args='-m 2048 -s 256 -p 128KiB -O 256'
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
  printf 'warning: stock recovery image not found; building stockless UBI recovery candidate\n' >&2
fi

cp "$boot_payload" "$boot_img"

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

file "$boot_img"
file "$recovery_img"
sha256sum "$boot_img" "$ubi_payload" "$recovery_img" >"$out_dir/SHA256SUMS"

printf 'Phase 3 lean mainline recovery candidate is ready:\n'
cat "$out_dir/SHA256SUMS"
