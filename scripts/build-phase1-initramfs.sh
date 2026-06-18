#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

toolchain_dir=${TOOLCHAIN_DIR:-build/toolchains/arm-eabi-4.6}
kernel_src=${KERNEL_SRC:-build/sources/kernel-bld010009/kernel}
cc="$toolchain_dir/bin/arm-eabi-gcc"
out_dir='build/phase1/initramfs'
list="$out_dir/initramfs.list"

test -x "$cc" || {
  printf 'error: missing toolchain. Run ./scripts/fetch-android-toolchain.sh first.\n' >&2
  exit 1
}
test -f "$kernel_src/usr/gen_init_cpio.c" || ./scripts/fetch-sharp-kernel.sh

mkdir -p "$out_dir"

"$cc" -nostdlib -static -Wl,-N -o "$out_dir/mininit" initramfs/mininit.S
"$toolchain_dir/bin/arm-eabi-strip" "$out_dir/mininit"

cat >"$list" <<EOF
dir /dev 0755 0 0
dir /dev/graphics 0755 0 0
nod /dev/console 0600 0 0 c 5 1
nod /dev/fb0 0600 0 0 c 29 0
nod /dev/graphics/fb0 0600 0 0 c 29 0
file /init $repo_root/$out_dir/mininit 0755 0 0
EOF

gcc -o "$out_dir/gen_init_cpio" "$kernel_src/usr/gen_init_cpio.c"
"$out_dir/gen_init_cpio" "$list" >"$out_dir/initramfs.cpio"
gzip -n -c "$out_dir/initramfs.cpio" >"$out_dir/initramfs.cpio.gz"

printf 'Phase 1 initramfs is ready:\n'
sha256sum "$out_dir/mininit" "$out_dir/initramfs.cpio" "$out_dir/initramfs.cpio.gz"
