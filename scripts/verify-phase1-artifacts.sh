#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

test -s build/phase1/initramfs/mininit || fail 'missing mininit'
test -s build/phase1/initramfs/initramfs.cpio || fail 'missing initramfs.cpio'
test -s build/phase1/initramfs/initramfs.cpio.gz || fail 'missing initramfs.cpio.gz'
test -s build/kernel-out/arch/arm/boot/zImage || fail 'missing zImage'
test -s build/phase1/recovery/phase1-boot.img || fail 'missing phase1-boot.img'
test -s build/phase1/recovery/phase1-boot-volume.bin || fail 'missing phase1-boot-volume.bin'
test -s build/phase1/recovery/phase1-recovery.img || fail 'missing phase1-recovery.img'

file build/phase1/initramfs/mininit | grep -E 'ELF 32-bit.*ARM' >/dev/null || fail 'mininit is not an ARM ELF'
strings build/phase1/initramfs/mininit | grep 'rebooting in 20 seconds' >/dev/null || fail 'mininit is missing timed reboot signal'
gzip -t build/phase1/initramfs/initramfs.cpio.gz
cpio_listing=$(gzip -dc build/phase1/initramfs/initramfs.cpio.gz | cpio -it 2>/dev/null)
printf '%s\n' "$cpio_listing" | grep '^/dev/fb0$' >/dev/null || fail 'initramfs is missing /dev/fb0'
printf '%s\n' "$cpio_listing" | grep '^/dev/graphics/fb0$' >/dev/null || fail 'initramfs is missing /dev/graphics/fb0'
file build/kernel-out/arch/arm/boot/zImage | grep 'Linux kernel ARM boot executable zImage' >/dev/null || fail 'zImage is not an ARM zImage'
file build/phase1/recovery/phase1-boot.img | grep 'Android bootimg' >/dev/null || fail 'phase1 boot image is not an Android bootimg'
file build/phase1/recovery/phase1-recovery.img | grep 'UBI image' >/dev/null || fail 'phase1 recovery image is not a UBI image'
[ "$(wc -c <build/phase1/recovery/phase1-recovery.img)" -eq 11534336 ] || fail 'phase1 recovery image size does not match mtd2'
[ "$(wc -c <build/phase1/recovery/phase1-boot-volume.bin)" -eq 9547776 ] || fail 'phase1 UBI volume payload size does not match stock recovery'
./scripts/check-ubi-layout.py --expect-vid-offset 256 --expect-data-offset 2048 --expect-pebs 76 build/phase1/recovery/phase1-recovery.img
./scripts/test-ubi-volume-extract.sh

mkdir -p build/phase1
sha256sum \
  build/phase1/initramfs/mininit \
  build/phase1/initramfs/initramfs.cpio \
  build/phase1/initramfs/initramfs.cpio.gz \
  build/phase1/recovery/phase1-boot.img \
  build/phase1/recovery/phase1-boot-volume.bin \
  build/phase1/recovery/phase1-recovery.img \
  build/kernel-out/arch/arm/boot/zImage \
  >build/phase1/SHA256SUMS

printf 'Phase 1 artifacts verified:\n'
cat build/phase1/SHA256SUMS
