#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

version=${MAINLINE_KERNEL_VERSION:-6.12.94}
kernel_src=${KERNEL_SRC:-build/sources/linux-$version}
kernel_out=${KERNEL_OUT:-build/phase3/lean-kernel-out}
cross_compile=${CROSS_COMPILE:-arm-linux-gnueabi-}
out_dir='build/phase3/lean-boot'
dtb="$out_dir/qcom-qsd8x50-is01.dtb"
zimage="$kernel_out/arch/arm/boot/zImage"
zimage_dtb="$out_dir/zImage-dtb"
ramdisk='build/phase3/initramfs/initramfs.cpio'
boot_img="$out_dir/phase3-mainline-lean-boot.img"
fragment='configs/mainline/is01_phase3_lean.fragment'
dts='board/is01/phase3/qcom-qsd8x50-is01.dts'

test -d "$kernel_src" || ./scripts/fetch-mainline-kernel.sh
test -s "$ramdisk" || ./scripts/build-phase3-initramfs.sh
command -v dtc >/dev/null 2>&1 || {
  printf 'error: dtc not found. Install device-tree-compiler.\n' >&2
  exit 1
}
command -v "${cross_compile}gcc" >/dev/null 2>&1 || {
  printf 'error: missing ARM cross compiler: %sgcc\n' "$cross_compile" >&2
  exit 1
}

mkdir -p "$kernel_out" "$out_dir"

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
  --cmdline 'rdinit=/init init=/init root=/dev/ram0 rw panic=20 ignore_loglevel androidboot.hardware=qcom'

file "$zimage"
file "$dtb"
file "$zimage_dtb"
file "$ramdisk"
file "$boot_img"
sha256sum "$zimage" "$dtb" "$zimage_dtb" "$ramdisk" "$boot_img" >"$out_dir/SHA256SUMS"

printf 'Phase 3 lean mainline boot payload is ready:\n'
cat "$out_dir/SHA256SUMS"
