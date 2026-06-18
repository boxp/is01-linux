# IS01 source map

This file maps the observed stock device build to reproducible source inputs used by this repository.

## Stock device

- device: au/Sharp IS01
- observed build: `01.00.09`
- observed kernel: `Linux localhost 2.6.29-perf #1 PREEMPT Sun Feb 13 23:06:01 JST 2011 armv7l GNU/Linux`
- observed Android version: `1.6`
- observed SoC family: Qualcomm QSD8x50 / MSM
- stock config source: `configs/is01-stock.config`

## Sharp GPL kernel source

- upstream page: <https://k-tai.sharp.co.jp/support/developers/oss/is01/index.html>
- source archive: `kernel.tar.gz`
- source URL: `http://ad-dl02.4sh.jp/developers/oss/is01/index_v2/download/bld010009/kernel.tar.gz`
- expected sha256: `950adf03dc3db447c24c60109a20db4015941ed0bdb55b4941c2143665b415e4`
- local download path: `build/sources/is01-bld010009-kernel.tar.gz`
- extracted path: `build/sources/kernel-bld010009/kernel`

## Kernel config baseline

The stock `/proc/config.gz` matches the QSD8x50 COMET/DECKARD family:

- `CONFIG_ARCH_MSM=y`
- `CONFIG_ARCH_QSD8X50=y`
- `CONFIG_MACH_QSD8X50_COMET=y`
- `CONFIG_MACH_DECKARD=y`
- `CONFIG_CMDLINE="init=/sbin/init root=/dev/ram rw initrd=0x11000000,16M console=ttyDCC0 mem=88M"`

Phase 1 uses the captured stock config rather than a guessed defconfig.

## Stock recovery image format

The stock `mtd2-recovery.img` backup is a UBI image with one dynamic volume named `boot`. The extracted `boot` volume is an Android boot image with:

- kernel address: `0x20008000`
- ramdisk address: `0x24000000`
- second address: `0x20f00000`
- tags address: `0x20000100`
- page size: `2048`
- cmdline: `console=ttyMSM2,115200n8 androidboot.hardware=qcom`
- recovery partition size: `11,534,336`
- UBI min I/O size: `256`
- UBI physical eraseblock size: `131072`
- UBI VID header offset: `256`

Phase 1 uses these constants to generate `build/phase1/recovery/phase1-recovery.img` without committing the stock backup.

## Toolchain

The Phase 1 build scripts use Android's prebuilt `arm-eabi-4.6` toolchain from AOSP:

- upstream: <https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-eabi-4.6>
- branch: `jb-release`
- commit: `b4ecd7806d8f46cddeacaf9f8de92c191fb266e4`
- local path: `build/toolchains/arm-eabi-4.6`

The toolchain binaries are 32-bit Linux executables. On Ubuntu/GitHub Actions, install `libc6-i386` and `lib32z1` before running the kernel build.
