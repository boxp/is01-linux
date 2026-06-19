#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

toolchain_dir=${TOOLCHAIN_DIR:-build/toolchains/arm-eabi-4.6}
kernel_src=${KERNEL_SRC:-build/sources/kernel-bld010009/kernel}
cc="$toolchain_dir/bin/arm-eabi-gcc"
out_dir='build/phase2/initramfs'
list="$out_dir/initramfs.list"
issue="$out_dir/issue"

test -x "$cc" || {
  printf 'error: missing toolchain. Run ./scripts/fetch-android-toolchain.sh first.\n' >&2
  exit 1
}
test -f "$kernel_src/usr/gen_init_cpio.c" || ./scripts/fetch-sharp-kernel.sh

mkdir -p "$out_dir"

"$cc" -nostdlib -static -ffreestanding -fno-builtin -Wl,-N -o "$out_dir/phase2-init" initramfs/phase2-init.c
"$toolchain_dir/bin/arm-eabi-strip" "$out_dir/phase2-init"

cat >"$issue" <<'EOF'
is01 phase2 userspace

Use the built-in /init shell on /dev/console.
Commands: help status fb cat jp reboot
EOF

cat >"$list" <<EOF
dir /dev 0755 0 0
dir /dev/graphics 0755 0 0
dir /dev/input 0755 0 0
dir /proc 0555 0 0
dir /sys 0555 0 0
dir /tmp 0777 0 0
dir /etc 0755 0 0
dir /bin 0755 0 0
dir /root 0700 0 0
nod /dev/console 0600 0 0 c 5 1
nod /dev/null 0666 0 0 c 1 3
nod /dev/zero 0666 0 0 c 1 5
nod /dev/tty0 0600 0 0 c 4 0
nod /dev/tty1 0600 0 0 c 4 1
nod /dev/fb0 0600 0 0 c 29 0
nod /dev/graphics/fb0 0600 0 0 c 29 0
nod /dev/input/event0 0600 0 0 c 13 64
nod /dev/input/event1 0600 0 0 c 13 65
nod /dev/input/event2 0600 0 0 c 13 66
nod /dev/input/event3 0600 0 0 c 13 67
nod /dev/input/event4 0600 0 0 c 13 68
nod /dev/input/event5 0600 0 0 c 13 69
nod /dev/input/event6 0600 0 0 c 13 70
nod /dev/input/event7 0600 0 0 c 13 71
file /init $repo_root/$out_dir/phase2-init 0755 0 0
file /bin/sh $repo_root/$out_dir/phase2-init 0755 0 0
file /etc/issue $repo_root/$issue 0644 0 0
EOF

gcc -o "$out_dir/gen_init_cpio" "$kernel_src/usr/gen_init_cpio.c"
"$out_dir/gen_init_cpio" "$list" >"$out_dir/initramfs.cpio"
gzip -n -c "$out_dir/initramfs.cpio" >"$out_dir/initramfs.cpio.gz"

printf 'Phase 2 initramfs is ready:\n'
sha256sum "$out_dir/phase2-init" "$out_dir/initramfs.cpio" "$out_dir/initramfs.cpio.gz"
