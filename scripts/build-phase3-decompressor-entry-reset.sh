#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

version=${MAINLINE_KERNEL_VERSION:-6.12.94}
kernel_src=${KERNEL_SRC:-build/sources/linux-$version}
kernel_out=${KERNEL_OUT:-build/phase3/decompressor-entry-reset-kernel-out}
cross_compile=${CROSS_COMPILE:-arm-linux-gnueabi-}
stock_recovery=${STOCK_RECOVERY_IMG:-/home/boxp/Documents/obsidian-headless/BOXP/Projects/is01/artifacts/backups/stock-20260618T142509Z/stock-20260618T142509Z/mtd2-recovery.img}
out_dir='build/phase3/decompressor-entry-reset'
head_s="$kernel_src/arch/arm/boot/compressed/head.S"
fragment='configs/mainline/is01_phase3_lean.fragment'
zimage="$kernel_out/arch/arm/boot/zImage"
ramdisk='build/phase3/initramfs/initramfs.cpio'
partition_size=11534336
volume_payload_size=9547776
ubinize_args='-m 2048 -s 256 -p 128KiB -O 256'
stock_kernel_size=5526688
stock_ramdisk_size=791552
stock_cmdline='console=ttyMSM2,115200n8 androidboot.hardware=qcom'
phase3_cmdline='rdinit=/init init=/init root=/dev/ram0 rw panic=20 ignore_loglevel androidboot.hardware=qcom'

test -d "$kernel_src" || ./scripts/fetch-mainline-kernel.sh
test -s "$ramdisk" || ./scripts/build-phase3-initramfs.sh
command -v "${cross_compile}gcc" >/dev/null 2>&1 || {
  printf 'error: missing ARM cross compiler: %sgcc\n' "$cross_compile" >&2
  exit 1
}
command -v ubinize >/dev/null 2>&1 || {
  printf 'error: ubinize not found. Install mtd-utils.\n' >&2
  exit 1
}
test -s "$head_s" || {
  printf 'error: missing Linux ARM compressed head: %s\n' "$head_s" >&2
  exit 1
}

mkdir -p "$kernel_out" "$out_dir"
patch_note="$out_dir/decompressor-entry-reset-patch.txt"
source_boot="$out_dir/source-stock-compatible-boot.img"
source_note="$out_dir/source-stock-compatible-boot.txt"
placeholder_kernel="$out_dir/source-stock-kernel-placeholder.bin"
placeholder_ramdisk="$out_dir/source-stock-ramdisk-placeholder.img"
padded_kernel="$out_dir/phase3-decompressor-entry-reset-stock-kernel-slot.bin"
padded_ramdisk="$out_dir/phase3-initramfs-stock-ramdisk-slot.cpio"

restore_head() {
  if [ -n "${head_backup:-}" ] && [ -f "$head_backup" ]; then
    cp "$head_backup" "$head_s"
    rm -f "$head_backup"
  fi
}
trap restore_head EXIT INT TERM

head_backup=$(mktemp)
cp "$head_s" "$head_backup"

python3 - "$head_s" "$patch_note" <<'PY'
from pathlib import Path
import sys

head = Path(sys.argv[1])
note = Path(sys.argv[2])
text = head.read_text()
needle = "1:\n ARM_BE8(\tsetend\tbe\t\t)\t@ go BE8 if compiled for BE8\n"
if needle not in text:
    raise SystemExit("error: could not find ARM decompressor post-header entry marker")
if ".Lis01_decompressor_entry_reset:" in text:
    raise SystemExit("error: IS01 decompressor entry reset patch is already present")

insertion = """1:
\t\tb\t.Lis01_decompressor_entry_reset

\t\t/*
\t\t * IS01 Phase 3 probe: if the real Linux decompressor reaches
\t\t * its post-zImage-header entry point, trigger the downstream
\t\t * proc_comm reset path before normal decompressor setup.
\t\t */
.Lis01_decompressor_entry_reset:
\t\tmrs\tr0, cpsr
\t\torr\tr0, r0, #0xc0
\t\tmsr\tcpsr_c, r0

\t\tldr\tr1, =0x00100000\t\t@ MSM shared RAM
\t\tldr\tr2, =0x00000001\t\t@ PCOM_READY
\t\tldr\tr8, =0x01000000
.Lis01_wait_ready:
\t\tldr\tr3, [r1, #0x14]\t\t@ MDM_STATUS
\t\tcmp\tr3, r2
\t\tbeq\t.Lis01_send_reset
\t\tsubs\tr8, r8, #1
\t\tbne\t.Lis01_wait_ready

.Lis01_send_reset:
\t\tmov\tr0, #0
\t\tstr\tr0, [r1, #0x08]\t\t@ APP_DATA1
\t\tstr\tr0, [r1, #0x0c]\t\t@ APP_DATA2
\t\tldr\tr0, =0x0000002a\t\t@ PCOM_RESET_CHIP_IMM
\t\tstr\tr0, [r1, #0x00]\t\t@ APP_COMMAND

\t\tmov\tr0, #0
\t\tmcr\tp15, 0, r0, c7, c10, 4
\t\tmcr\tp15, 0, r0, c7, c10, 5

\t\tldr\tr4, =0xac100000\t\t@ MSM_CSR
\t\tmov\tr5, #1
\t\tstr\tr5, [r4, #0x418]\t\t@ A2M_INT_6

\t\tmov\tr0, #0
\t\tmcr\tp15, 0, r0, c7, c10, 4
\t\tmcr\tp15, 0, r0, c7, c10, 5
.Lis01_reset_loop:
\t\tb\t.Lis01_reset_loop
\t\t.ltorg

 ARM_BE8(\tsetend\tbe\t\t)\t@ go BE8 if compiled for BE8
"""
head.write_text(text.replace(needle, insertion, 1))
note.write_text(
    "Patched arch/arm/boot/compressed/head.S after the zImage header label "
    "to trigger proc_comm reset before normal decompressor setup.\\n"
)
PY

make -C "$kernel_src" O="$repo_root/$kernel_out" ARCH=arm CROSS_COMPILE="$cross_compile" multi_v7_defconfig
(
  cd "$kernel_src"
  ARCH=arm CROSS_COMPILE="$cross_compile" ./scripts/kconfig/merge_config.sh \
    -O "$repo_root/$kernel_out" \
    "$repo_root/$kernel_out/.config" \
    "$repo_root/$fragment"
)
make -C "$kernel_src" O="$repo_root/$kernel_out" ARCH=arm CROSS_COMPILE="$cross_compile" olddefconfig
make -C "$kernel_src" O="$repo_root/$kernel_out" ARCH=arm CROSS_COMPILE="$cross_compile" -j"$(nproc)" zImage
restore_head
trap - EXIT INT TERM

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

python3 - "$zimage" "$padded_kernel" "$stock_kernel_size" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
slot_size = int(sys.argv[3])
data = src.read_bytes()
if len(data) > slot_size:
    raise SystemExit(f"patched zImage is larger than stock kernel slot: {len(data)} > {slot_size}")
dst.write_bytes(data + (b"\0" * (slot_size - len(data))))
PY

python3 - "$ramdisk" "$padded_ramdisk" "$stock_ramdisk_size" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
slot_size = int(sys.argv[3])
data = src.read_bytes()
if len(data) > slot_size:
    raise SystemExit(f"ramdisk payload is larger than stock ramdisk slot: {len(data)} > {slot_size}")
dst.write_bytes(data + (b"\0" * (slot_size - len(data))))
PY

boot_img="$out_dir/phase3-stockslot-decompressor-entry-reset-boot.img"
./scripts/repack-android-bootimg.py \
  --source "$source_boot" \
  --kernel "$padded_kernel" \
  --ramdisk "$padded_ramdisk" \
  --cmdline "$phase3_cmdline" \
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
  --expect-cmdline-contains 'rdinit=/init' \
  "$boot_img" >"$out_dir/phase3-stockslot-decompressor-entry-reset-boot-layout.txt"

ubi_payload="$out_dir/phase3-stockslot-decompressor-entry-reset-volume.bin"
ubi_img="$out_dir/phase3-stockslot-decompressor-entry-reset-recovery.ubi"
recovery_img="$out_dir/phase3-stockslot-decompressor-entry-reset-recovery.img"
ubinize_cfg="$out_dir/phase3-stockslot-decompressor-entry-reset-ubinize.cfg"

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

sha256sum \
  "$zimage" \
  "$padded_kernel" \
  "$padded_ramdisk" \
  "$boot_img" \
  "$ubi_payload" \
  "$recovery_img" \
  >"$out_dir/SHA256SUMS"

printf 'Phase 3 decompressor entry reset recovery candidate is ready:\n'
cat "$source_note"
cat "$patch_note"
cat "$out_dir/SHA256SUMS"
