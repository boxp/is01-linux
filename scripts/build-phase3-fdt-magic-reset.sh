#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

version=${MAINLINE_KERNEL_VERSION:-6.12.94}
kernel_src=${KERNEL_SRC:-build/sources/linux-$version}
kernel_out=${KERNEL_OUT:-build/phase3/fdt-magic-reset-kernel-out}
cross_compile=${CROSS_COMPILE:-arm-linux-gnueabi-}
stock_recovery=${STOCK_RECOVERY_IMG:-/home/boxp/Documents/obsidian-headless/BOXP/Projects/is01/artifacts/backups/stock-20260618T142509Z/stock-20260618T142509Z/mtd2-recovery.img}
out_dir='build/phase3/fdt-magic-reset'
head_s="$kernel_src/arch/arm/kernel/head.S"
devtree_c="$kernel_src/arch/arm/kernel/devtree.c"
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
  printf 'error: missing Linux ARM kernel head: %s\n' "$head_s" >&2
  exit 1
}
test -s "$devtree_c" || {
  printf 'error: missing Linux ARM devtree.c: %s\n' "$devtree_c" >&2
  exit 1
}

mkdir -p "$kernel_out" "$out_dir"
patch_note="$out_dir/fdt-magic-reset-patch.txt"
source_boot="$out_dir/source-stock-compatible-boot.img"
source_note="$out_dir/source-stock-compatible-boot.txt"
placeholder_kernel="$out_dir/source-stock-kernel-placeholder.bin"
placeholder_ramdisk="$out_dir/source-stock-ramdisk-placeholder.img"
padded_kernel="$out_dir/phase3-fdt-magic-reset-stock-kernel-slot.bin"
padded_ramdisk="$out_dir/phase3-initramfs-stock-ramdisk-slot.cpio"

restore_head() {
  if [ -n "${head_backup:-}" ] && [ -f "$head_backup" ]; then
    cp "$head_backup" "$head_s"
    rm -f "$head_backup"
  fi
  if [ -n "${devtree_c_backup:-}" ] && [ -f "$devtree_c_backup" ]; then
    cp "$devtree_c_backup" "$devtree_c"
    rm -f "$devtree_c_backup"
  fi
}
trap restore_head EXIT INT TERM

head_backup=$(mktemp)
cp "$head_s" "$head_backup"
devtree_c_backup=$(mktemp)
cp "$devtree_c" "$devtree_c_backup"

python3 - "$head_s" "$devtree_c" "$patch_note" <<'PY'
from pathlib import Path
import sys

head = Path(sys.argv[1])
devtree_c = Path(sys.argv[2])
note = Path(sys.argv[3])
text = head.read_text()
map_needle = """#ifdef CONFIG_ARM_LPAE
	sub	r4, r4, #0x1000		@ point to the PGD table
#endif
	ret	lr
ENDPROC(__create_page_tables)
"""
if map_needle not in text:
    raise SystemExit("error: could not find ARM __create_page_tables return marker")
if ".Lis01_map_proc_comm_for_fdt_magic_reset:" in text:
    raise SystemExit("error: IS01 fdt-magic reset patch is already present")

maps = """
	/*
	 * IS01 Phase 3 probe support: keep the downstream proc_comm
	 * scratch region and MSM_CSR reachable after the MMU is enabled.
	 * The reset signal below still uses physical addresses, so install
	 * temporary identity section mappings before entering __turn_mmu_on.
	 */
.Lis01_map_proc_comm_for_fdt_magic_reset:
#ifdef CONFIG_ARM_LPAE
#error IS01 fdt-magic proc_comm reset probe needs non-LPAE section mappings
#endif
\tldr\tr7, [r10, #PROCINFO_IO_MMUFLAGS]\t@ io_mmuflags
\tldr\tr5, =0x00100000\t\t@ MSM shared RAM
\tmov\tr5, r5, lsr #SECTION_SHIFT
\torr\tr3, r7, r5, lsl #SECTION_SHIFT
\tstr\tr3, [r4, r5, lsl #PMD_ENTRY_ORDER]
\tldr\tr5, =0xac100000\t\t@ MSM_CSR
\tmov\tr5, r5, lsr #SECTION_SHIFT
\torr\tr3, r7, r5, lsl #SECTION_SHIFT
\tstr\tr3, [r4, r5, lsl #PMD_ENTRY_ORDER]
"""

reset = """
\t/*
\t * IS01 Phase 3 probe: setup_machine_fdt() received a non-NULL
\t * dt_virt pointer whose first word matches FDT_MAGIC. Trigger the
\t * downstream proc_comm reset before early_init_dt_verify() so the
\t * next split can distinguish non-FDT handoff data from FDT header
\t * validation failure.
\t */
\tasm volatile(
\t\"mrs r0, cpsr\\n\"
\t\"orr r0, r0, #0xc0\\n\"
\t\"msr cpsr_c, r0\\n\"
\t\"ldr r1, =0x00100000\\n\"     /* MSM shared RAM */
\t\"ldr r2, =0x00000001\\n\"     /* PCOM_READY */
\t\"ldr r8, =0x01000000\\n\"
\t\"1:\\n\"
\t\"ldr r3, [r1, #0x14]\\n\"     /* MDM_STATUS */
\t\"cmp r3, r2\\n\"
\t\"beq 2f\\n\"
\t\"subs r8, r8, #1\\n\"
\t\"bne 1b\\n\"
\t\"2:\\n\"
\t\"mov r0, #0\\n\"
\t\"str r0, [r1, #0x08]\\n\"     /* APP_DATA1 */
\t\"str r0, [r1, #0x0c]\\n\"     /* APP_DATA2 */
\t\"ldr r0, =0x0000002a\\n\"     /* PCOM_RESET_CHIP_IMM */
\t\"str r0, [r1, #0x00]\\n\"     /* APP_COMMAND */
\t\"mov r0, #0\\n\"
\t\"mcr p15, 0, r0, c7, c10, 4\\n\"
\t\"mcr p15, 0, r0, c7, c10, 5\\n\"
\t\"ldr r4, =0xac100000\\n\"     /* MSM_CSR */
\t\"mov r5, #1\\n\"
\t\"str r5, [r4, #0x418]\\n\"    /* A2M_INT_6 */
\t\"mov r0, #0\\n\"
\t\"mcr p15, 0, r0, c7, c10, 4\\n\"
\t\"mcr p15, 0, r0, c7, c10, 5\\n\"
\t\"3: b 3b\\n\"
\t:
\t:
\t: \"r0\", \"r1\", \"r2\", \"r3\", \"r4\", \"r5\", \"r8\", \"memory\");
"""
text = text.replace(
    map_needle,
    maps + "\n" + map_needle,
    1,
)
head.write_text(text)

devtree_text = devtree_c.read_text()
if "IS01 Phase 3 probe: setup_machine_fdt() received a non-NULL" in devtree_text:
    raise SystemExit("error: IS01 fdt-magic reset patch is already present")
include_needle = "#include <linux/init.h>\n"
if "#include <linux/libfdt.h>\n" not in devtree_text:
    if include_needle not in devtree_text:
        raise SystemExit("error: could not find devtree.c include insertion point")
    devtree_text = devtree_text.replace(
        include_needle,
        include_needle + "#include <linux/libfdt.h>\n",
        1,
    )
verify_needle = """\tif (!dt_virt || !early_init_dt_verify(dt_virt, __pa(dt_virt)))
\t\treturn NULL;

\tmdesc = of_flat_dt_match_machine(mdesc_best, arch_get_next_mach);
"""
if verify_needle not in devtree_text:
    raise SystemExit("error: could not find setup_machine_fdt early_init_dt_verify block")
replacement = """\tif (!dt_virt)
\t\treturn NULL;

\tif (fdt_magic(dt_virt) == FDT_MAGIC) {
%s
\t}

\tif (!early_init_dt_verify(dt_virt, __pa(dt_virt)))
\t\treturn NULL;

\tmdesc = of_flat_dt_match_machine(mdesc_best, arch_get_next_mach);
""" % reset
devtree_c.write_text(devtree_text.replace(
    verify_needle,
    replacement,
    1,
))
note.write_text(
    "Patched arch/arm/kernel/head.S to identity-map proc_comm shared RAM "
    "and MSM_CSR in early page tables, then patched arch/arm/kernel/devtree.c "
    "to include linux/libfdt.h and trigger proc_comm reset when "
    "setup_machine_fdt() receives a non-NULL dt_virt pointer whose first word "
    "matches FDT_MAGIC, before "
    "early_init_dt_verify() validates the rest of the FDT header.\n"
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

boot_img="$out_dir/phase3-stockslot-fdt-magic-reset-boot.img"
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
  "$boot_img" >"$out_dir/phase3-stockslot-fdt-magic-reset-boot-layout.txt"

ubi_payload="$out_dir/phase3-stockslot-fdt-magic-reset-volume.bin"
ubi_img="$out_dir/phase3-stockslot-fdt-magic-reset-recovery.ubi"
recovery_img="$out_dir/phase3-stockslot-fdt-magic-reset-recovery.img"
ubinize_cfg="$out_dir/phase3-stockslot-fdt-magic-reset-ubinize.cfg"

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

printf 'Phase 3 fdt-magic reset recovery candidate is ready:\n'
cat "$source_note"
cat "$patch_note"
cat "$out_dir/SHA256SUMS"
