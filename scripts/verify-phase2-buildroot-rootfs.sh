#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

defconfig='configs/buildroot/is01_phase2_defconfig'
device_table='board/is01/phase2/device_table.txt'
post_build='board/is01/phase2/post-build.sh'
out_dir=${PHASE2_BUILDROOT_OUT:-build/phase2/buildroot}
rootfs="$out_dir/images/rootfs.cpio"
partition_payload_limit=9547776

test -f "$defconfig" || fail "missing $defconfig"
test -f "$device_table" || fail "missing $device_table"
test -x "$post_build" || fail "missing executable $post_build"

grep -F 'BR2_DEFAULT_KERNEL_VERSION="2.6.29"' "$defconfig" >/dev/null || fail 'Buildroot defconfig must pin Linux 2.6.29 headers'
grep -F 'BR2_TOOLCHAIN_BUILDROOT_UCLIBC=y' "$defconfig" >/dev/null || fail 'Buildroot defconfig must use the internal uClibc toolchain'
grep -F 'BR2_STATIC_LIBS=y' "$defconfig" >/dev/null || fail 'Buildroot defconfig must request static target binaries'
grep -F 'BR2_PACKAGE_BUSYBOX=y' "$defconfig" >/dev/null || fail 'Buildroot defconfig must include BusyBox'
grep -F 'BR2_PACKAGE_DROPBEAR=y' "$defconfig" >/dev/null || fail 'Buildroot defconfig must include Dropbear'
grep -F 'BR2_PACKAGE_DROPBEAR_CLIENT=y' "$defconfig" >/dev/null || fail 'Buildroot defconfig must include the Dropbear client'
grep -F 'BR2_TARGET_ROOTFS_CPIO=y' "$defconfig" >/dev/null || fail 'Buildroot defconfig must emit a cpio rootfs'
grep -F '/dev/graphics/fb0 c' "$device_table" >/dev/null || fail 'device table must include /dev/graphics/fb0'
grep -F '/dev/input/event0 c' "$device_table" >/dev/null || fail 'device table must include input events'

if [ ! -s "$rootfs" ]; then
  printf 'Phase 2 Buildroot rootfs config verified; rootfs image is not built yet: %s\n' "$rootfs"
  exit 0
fi

[ "$(head -c 6 "$rootfs")" = '070701' ] || fail 'rootfs is not an uncompressed newc cpio archive'
[ "$(wc -c <"$rootfs")" -le "$partition_payload_limit" ] || fail 'rootfs cpio is larger than the stock recovery UBI payload area'

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT INT TERM

cpio_listing=$(cpio -itv <"$rootfs" 2>/dev/null)

(cd "$tmp_dir" && cpio -id --quiet \
  bin/busybox \
  usr/sbin/dropbear \
  usr/bin/dbclient \
  usr/bin/ssh \
  init \
  etc/motd \
  etc/network/interfaces \
  <"$repo_root/$rootfs")

test -x "$tmp_dir/bin/busybox" || fail 'rootfs is missing /bin/busybox'
test -x "$tmp_dir/usr/sbin/dropbear" || fail 'rootfs is missing /usr/sbin/dropbear'
test -L "$tmp_dir/usr/bin/dbclient" || fail 'rootfs is missing /usr/bin/dbclient symlink'
test -L "$tmp_dir/usr/bin/ssh" || fail 'rootfs is missing /usr/bin/ssh symlink'
test -L "$tmp_dir/init" || fail 'rootfs is missing /init symlink'
printf '%s\n' "$cpio_listing" | grep -E '^c.* dev/console$' >/dev/null || fail 'rootfs is missing static /dev/console'
printf '%s\n' "$cpio_listing" | grep -E '^c.* dev/graphics/fb0$' >/dev/null || fail 'rootfs is missing static framebuffer node'
printf '%s\n' "$cpio_listing" | grep -E '^c.* dev/input/event0$' >/dev/null || fail 'rootfs is missing static input node'
grep -F '日本語 UTF-8' "$tmp_dir/etc/motd" >/dev/null || fail 'rootfs motd is missing Japanese UTF-8 probe text'
grep -F 'usb0' "$tmp_dir/etc/network/interfaces" >/dev/null || fail 'rootfs is missing usb0 network stub'

file "$tmp_dir/bin/busybox" | grep -E 'ELF 32-bit.*ARM.*statically linked' >/dev/null || fail 'BusyBox is not a static ARM ELF'
file "$tmp_dir/usr/sbin/dropbear" | grep -E 'ELF 32-bit.*ARM.*statically linked' >/dev/null || fail 'Dropbear is not a static ARM ELF'

sha256sum "$rootfs" >"$out_dir/SHA256SUMS"

printf 'Phase 2 Buildroot rootfs verified:\n'
cat "$out_dir/SHA256SUMS"
