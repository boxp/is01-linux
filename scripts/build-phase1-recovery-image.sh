#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

out_dir='build/phase1/recovery'
boot_img="$out_dir/phase1-boot.img"
ubi_payload="$out_dir/phase1-boot-volume.bin"
ubi_img="$out_dir/phase1-recovery.ubi"
recovery_img="$out_dir/phase1-recovery.img"
ubinize_cfg="$out_dir/ubinize.cfg"

zimage='build/kernel-out/arch/arm/boot/zImage'
ramdisk='build/phase1/initramfs/initramfs.cpio.gz'
partition_size=11534336
volume_payload_size=9547776

test -s "$zimage" || ./scripts/build-phase1-kernel.sh
test -s "$ramdisk" || ./scripts/build-phase1-initramfs.sh
command -v ubinize >/dev/null 2>&1 || {
  printf 'error: ubinize not found. Install mtd-utils.\n' >&2
  exit 1
}

mkdir -p "$out_dir"

./scripts/mkbootimg.py \
  --kernel "$zimage" \
  --ramdisk "$ramdisk" \
  --output "$boot_img" \
  --kernel-addr 0x20008000 \
  --ramdisk-addr 0x24000000 \
  --second-addr 0x20f00000 \
  --tags-addr 0x20000100 \
  --page-size 2048 \
  --cmdline 'console=ttyMSM2,115200n8 androidboot.hardware=qcom'

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

ubinize -o "$ubi_img" -m 2048 -s 256 -p 128KiB -O 256 "$ubinize_cfg"

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
sha256sum "$boot_img" "$ubi_payload" "$recovery_img"
