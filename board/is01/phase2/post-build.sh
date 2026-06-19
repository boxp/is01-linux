#!/bin/sh
set -eu

target_dir=${1:?target directory is required}

ln -sf /sbin/init "$target_dir/init"

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
