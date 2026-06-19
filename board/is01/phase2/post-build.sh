#!/bin/sh
set -eu

target_dir=${1:?target directory is required}
board_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
host_dir=${HOST_DIR:-}
target_cc=${TARGET_CC:-}

if [ -z "$target_cc" ] && [ -n "$host_dir" ]; then
  target_cc="$host_dir/usr/bin/arm-buildroot-linux-uclibcgnueabi-gcc"
fi

test -n "$target_cc" || {
  printf 'error: TARGET_CC is not set and HOST_DIR is unavailable\n' >&2
  exit 1
}

ln -sf /sbin/init "$target_dir/init"
mkdir -p "$target_dir/sbin" "$target_dir/etc/init.d"

"$target_cc" -Os -static -s -o "$target_dir/sbin/is01-fbmark" "$board_dir/fbmark.c"

cat >"$target_dir/etc/init.d/S00is01-boot-probe" <<'EOF'
#!/bin/sh

echo 'IS01 Phase 2 Buildroot boot probe: rcS reached' >/dev/console 2>/dev/null || true
(
	sleep 20
	echo 'IS01 Phase 2 Buildroot boot probe: timed reboot' >/dev/console 2>/dev/null || true
	reboot -f
) &
/sbin/is01-fbmark >/dev/console 2>&1 || true
EOF
chmod 0755 "$target_dir/etc/init.d/S00is01-boot-probe"

cat >"$target_dir/etc/inittab" <<'EOF'
::sysinit:/etc/init.d/rcS
tty1::respawn:/bin/sh
console::respawn:/bin/sh
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/umount -a -r
EOF

cat >"$target_dir/etc/profile" <<'EOF'
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export HOME=/root
export TERM=${TERM:-linux}
export LANG=C.UTF-8
alias ll='ls -l'
EOF

cat >"$target_dir/etc/motd" <<'EOF'
IS01 Phase 2 Buildroot userspace

Checkpoints:
- BusyBox shell on the stock Linux 2.6.29 recovery kernel
- static Dropbear dbclient/ssh client
- framebuffer and input device nodes
- UTF-8/Japanese display probe: 日本語 UTF-8
EOF
