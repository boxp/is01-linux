#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

out_dir='build/phase3/initramfs'
init="$out_dir/phase3-init"
cpio_img="$out_dir/initramfs.cpio"
list_file="$out_dir/initramfs.list"
listing="$out_dir/initramfs.cpio.list"

test -s "$init" || fail "missing $init"
test -s "$cpio_img" || fail "missing $cpio_img"
test -s "$list_file" || fail "missing $list_file"

file "$init" | grep -E 'ELF 32-bit.*ARM.*statically linked' >/dev/null || fail 'phase3 init is not a static ARM ELF'
python3 - "$cpio_img" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
data = path.read_bytes()
if not data.startswith(b"070701"):
    raise SystemExit(f"error: {path} does not start with newc cpio magic")
PY

cpio -it <"$cpio_img" >"$listing" 2>/dev/null

for entry in /init /dev /dev/console /dev/null /proc /sys /tmp; do
  grep -Fx "$entry" "$listing" >/dev/null || fail "initramfs is missing $entry"
done

grep -F 'is01 phase3 mainline minimal init' "$init" >/dev/null || fail 'phase3 init banner is missing'
grep -F 'rebooting in 20 seconds' "$init" >/dev/null || fail 'phase3 reboot marker is missing'

sha256sum "$init" "$cpio_img" >"$out_dir/SHA256SUMS"

printf 'Phase 3 initramfs verified:\n'
cat "$out_dir/SHA256SUMS"
