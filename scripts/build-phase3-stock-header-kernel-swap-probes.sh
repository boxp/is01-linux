#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

stock_recovery=${STOCK_RECOVERY_IMG:-/home/boxp/Documents/obsidian-headless/BOXP/Projects/is01/artifacts/backups/stock-20260618T142509Z/stock-20260618T142509Z/mtd2-recovery.img}
out_dir='build/phase3/stock-header-kernel-swap-probes'
partition_size=11534336
volume_payload_size=9547776
ubinize_args='-m 2048 -s 256 -p 128KiB -O 256'
stock_kernel_size=5526688
stock_ramdisk_size=791552
stock_cmdline='console=ttyMSM2,115200n8 androidboot.hardware=qcom'
cc=${CROSS_COMPILE:-arm-linux-gnueabi-}gcc
objcopy=${CROSS_COMPILE:-arm-linux-gnueabi-}objcopy

command -v "$cc" >/dev/null 2>&1 || {
  printf 'error: %s not found. Install gcc-arm-linux-gnueabi or set CROSS_COMPILE.\n' "$cc" >&2
  exit 1
}
command -v "$objcopy" >/dev/null 2>&1 || {
  printf 'error: %s not found. Install gcc-arm-linux-gnueabi or set CROSS_COMPILE.\n' "$objcopy" >&2
  exit 1
}
command -v ubinize >/dev/null 2>&1 || {
  printf 'error: ubinize not found. Install mtd-utils.\n' >&2
  exit 1
}

mkdir -p "$out_dir"
source_boot="$out_dir/source-stock-compatible-boot.img"
source_note="$out_dir/source-stock-compatible-boot.txt"
placeholder_kernel="$out_dir/source-stock-kernel-placeholder.bin"
placeholder_ramdisk="$out_dir/source-stock-ramdisk-placeholder.img"

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
  ./scripts/extract-ubi-volume.py \
    --vol-id 0 \
    --trim-android-bootimg \
    --android-bootimg-align-size 4096 \
    "$stock_recovery" \
    "$source_boot" >/dev/null
  printf 'source: extracted from %s\n' "$stock_recovery" >"$source_note"
else
  printf 'warning: stock recovery image not found; building synthetic stock-compatible source boot image\n' >&2
  python3 - "$placeholder_kernel" "$placeholder_ramdisk" "$stock_kernel_size" "$stock_ramdisk_size" <<'PY'
from pathlib import Path
import sys

kernel = Path(sys.argv[1])
ramdisk = Path(sys.argv[2])
kernel_size = int(sys.argv[3])
ramdisk_size = int(sys.argv[4])
kernel.write_bytes(b"\0" * kernel_size)
ramdisk.write_bytes(b"070701" + (b"\0" * (ramdisk_size - 6)))
PY
  ./scripts/mkbootimg.py \
    --kernel "$placeholder_kernel" \
    --ramdisk "$placeholder_ramdisk" \
    --output "$source_boot" \
    --kernel-addr 0x20008000 \
    --ramdisk-addr 0x24000000 \
    --second-addr 0x20f00000 \
    --tags-addr 0x20000100 \
    --page-size 2048 \
    --image-align-size 4096 \
    --cmdline "$stock_cmdline" \
    --name ''
  {
    printf 'source: synthetic stock-compatible boot image\n'
    printf 'reason: STOCK_RECOVERY_IMG was not available in this environment\n'
  } >"$source_note"
fi

./scripts/inspect-android-bootimg.py \
  --image-align-size 4096 \
  --expect-page-size 2048 \
  --expect-align-size 4096 \
  --expect-kernel-addr 0x20008000 \
  --expect-ramdisk-addr 0x24000000 \
  --expect-second-addr 0x20f00000 \
  --expect-tags-addr 0x20000100 \
  --expect-cmdline-contains "$stock_cmdline" \
  "$source_boot" >"$out_dir/source-stock-compatible-boot-layout.txt"

build_payload() {
  slug=$1
  source=$2
  elf="$out_dir/$slug.elf"
  bin="$out_dir/$slug.bin"

  "$cc" \
    -nostdlib \
    -ffreestanding \
    -fno-pic \
    -fno-pie \
    -Wl,-Ttext=0x20008000 \
    -Wl,--build-id=none \
    -o "$elf" \
    "$source"
  "$objcopy" -O binary "$elf" "$bin"
}

pad_kernel_slot() {
  src=$1
  dst=$2
  python3 - "$src" "$dst" "$stock_kernel_size" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
stock_kernel_size = int(sys.argv[3])
data = src.read_bytes()
if len(data) > stock_kernel_size:
    raise SystemExit(f"payload is larger than stock kernel slot: {len(data)} > {stock_kernel_size}")
dst.write_bytes(data + (b"\0" * (stock_kernel_size - len(data))))
PY
}

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

build_probe() {
  slug=$1
  payload_source=$2
  payload_bin="$out_dir/$slug.bin"
  padded_kernel="$out_dir/$slug-stock-kernel-slot.bin"
  boot_img="$out_dir/$slug-boot.img"

  build_payload "$slug" "$payload_source"
  pad_kernel_slot "$payload_bin" "$padded_kernel"

  ./scripts/repack-android-bootimg.py \
    --source "$source_boot" \
    --kernel "$padded_kernel" \
    --image-align-size 4096 \
    --output "$boot_img"

  ./scripts/inspect-android-bootimg.py \
    --image-align-size 4096 \
    --expect-page-size 2048 \
    --expect-align-size 4096 \
    --expect-kernel-addr 0x20008000 \
    --expect-ramdisk-addr 0x24000000 \
    --expect-second-addr 0x20f00000 \
    --expect-tags-addr 0x20000100 \
    --expect-cmdline-contains "$stock_cmdline" \
    "$boot_img" >"$out_dir/$slug-boot-layout.txt"

  package_recovery "$boot_img" "$slug"
}

build_probe \
  phase3-stockslot-proc-comm-reset \
  payloads/phase3/proc-comm-reset.S

build_probe \
  phase3-stockslot-zimage-proc-comm-reset \
  payloads/phase3/zimage-proc-comm-reset.S

build_probe \
  phase3-stockslot-control-loop \
  payloads/phase3/early-loop.S

sha256sum \
  "$out_dir"/*.elf \
  "$out_dir"/*.bin \
  "$out_dir"/*-boot.img \
  "$out_dir"/*-volume.bin \
  "$out_dir"/*-recovery.img \
  >"$out_dir/SHA256SUMS"

printf 'Phase 3 stock-header kernel-swap recovery candidates are ready:\n'
cat "$source_note"
cat "$out_dir/SHA256SUMS"
