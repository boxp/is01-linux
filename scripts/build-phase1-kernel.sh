#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

kernel_src=${KERNEL_SRC:-build/sources/kernel-bld010009/kernel}
toolchain_dir=${TOOLCHAIN_DIR:-build/toolchains/arm-eabi-4.6}
out_dir=${KERNEL_OUT:-build/kernel-out}
initramfs_list="$repo_root/build/phase1/initramfs/initramfs.list"

abs_path() {
	case $1 in
		/*) printf '%s\n' "$1" ;;
		*) printf '%s/%s\n' "$repo_root" "$1" ;;
	esac
}

kernel_src_abs=$(abs_path "$kernel_src")
toolchain_dir_abs=$(abs_path "$toolchain_dir")
out_dir_abs=$(abs_path "$out_dir")
cross_compile="$toolchain_dir_abs/bin/arm-eabi-"

test -f "$kernel_src_abs/Makefile" || ./scripts/fetch-sharp-kernel.sh
test -x "$toolchain_dir_abs/bin/arm-eabi-gcc" || ./scripts/fetch-android-toolchain.sh
test -f "$initramfs_list" || ./scripts/build-phase1-initramfs.sh

mkdir -p "$out_dir_abs"
cp configs/is01-stock.config "$out_dir_abs/.config"

sed -i "s|^CONFIG_INITRAMFS_SOURCE=.*|CONFIG_INITRAMFS_SOURCE=\"$initramfs_list\"|" "$out_dir_abs/.config"

kcflags=${KCFLAGS:--Wno-error}

yes '' | make -C "$kernel_src_abs" O="$out_dir_abs" ARCH=arm CROSS_COMPILE="$cross_compile" KCFLAGS="$kcflags" oldconfig
make -C "$kernel_src_abs" O="$out_dir_abs" ARCH=arm CROSS_COMPILE="$cross_compile" KCFLAGS="$kcflags" -j"${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 2)}" zImage

sha256sum "$out_dir_abs/arch/arm/boot/zImage"
