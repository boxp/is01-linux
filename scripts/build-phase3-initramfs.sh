#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

version=${MAINLINE_KERNEL_VERSION:-6.12.94}
toolchain_prefix=${CROSS_COMPILE:-arm-linux-gnueabi-}
kernel_src=${KERNEL_SRC:-build/sources/linux-$version}
cc="${toolchain_prefix}gcc"
strip="${toolchain_prefix}strip"
out_dir='build/phase3/initramfs'
list="$out_dir/initramfs.list"

command -v "$cc" >/dev/null 2>&1 || {
  printf 'error: missing ARM cross compiler: %s\n' "$cc" >&2
  printf 'Install gcc-arm-linux-gnueabi or set CROSS_COMPILE.\n' >&2
  exit 1
}
command -v "$strip" >/dev/null 2>&1 || {
  printf 'error: missing ARM strip tool: %s\n' "$strip" >&2
  exit 1
}
test -f "$kernel_src/usr/gen_init_cpio.c" || ./scripts/fetch-mainline-kernel.sh

mkdir -p "$out_dir"

"$cc" -nostdlib -static -ffreestanding -fno-builtin -Wl,-N -o "$out_dir/phase3-init" initramfs/phase3-init.c
"$strip" "$out_dir/phase3-init"

cat >"$list" <<EOF
dir /dev 0755 0 0
dir /proc 0555 0 0
dir /sys 0555 0 0
dir /tmp 0777 0 0
nod /dev/console 0600 0 0 c 5 1
nod /dev/null 0666 0 0 c 1 3
file /init $repo_root/$out_dir/phase3-init 0755 0 0
EOF

gcc -o "$out_dir/gen_init_cpio" "$kernel_src/usr/gen_init_cpio.c"
"$out_dir/gen_init_cpio" "$list" >"$out_dir/initramfs.cpio"
gzip -n -c "$out_dir/initramfs.cpio" >"$out_dir/initramfs.cpio.gz"

printf 'Phase 3 initramfs is ready:\n'
sha256sum "$out_dir/phase3-init" "$out_dir/initramfs.cpio" "$out_dir/initramfs.cpio.gz"
