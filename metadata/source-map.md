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

## Phase 3 mainline Linux source

Phase 3 starts from a pinned longterm mainline Linux source archive and keeps the first observable signal independent of UART:

- upstream page: <https://www.kernel.org/>
- source archive: `linux-6.12.94.tar.xz`
- source URL: `https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.94.tar.xz`
- expected sha256: `e998a232b9418db3301cb58468e291a4f41d6ab8306029b30d991f56251dc8d2`
- local download path: `build/sources/linux-6.12.94.tar.xz`
- extracted path: `build/sources/linux-6.12.94`

The Phase 3 initial device description is `board/is01/phase3/qcom-qsd8x50-is01.dts`. The first initramfs userspace signal is a 20-second delayed reboot from `/init`; UART discovery is treated as optional auxiliary work rather than a completion gate.

After the first merged Phase 3 mainline candidate stopped at the stock splash screen with no timed reboot, `scripts/build-phase3-mainline-boot-entry-probes.sh` was added to generate recovery candidates that keep the same kernel/initramfs payload but vary Android boot header cmdline and section alignment. The expected output directory is `build/phase3/boot-entry-probes/`.

`configs/mainline/is01_phase3_lean.fragment` and the `phase3-mainline-lean-*` targets keep the same QSD8x50 DTS, Android boot addresses, and timed reboot initramfs signal, but disable obvious non-boot subsystems to reduce kernel payload size for the next early-boot cut.

After the lean mainline candidate also stopped at the stock splash screen with no timed reboot, `scripts/extract-phase3-downstream-board-info.sh` and `metadata/phase3-downstream-board-audit.md` record the Sharp downstream `DECKARD` board handoff facts. The extracted facts confirm `MACH_DECKARD` `2008030`, downstream `.boot_params` `0x20000100`, `PHYS_OFFSET` `0x20000000`, and stock `mem=88M`, so the next Phase 3 cuts should focus on machine/DT handoff assumptions or an earlier external signal rather than Android boot header page alignment.
