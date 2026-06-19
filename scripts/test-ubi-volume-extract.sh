#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

src_boot='build/phase1/recovery/phase1-boot.img'
src_ubi='build/phase1/recovery/phase1-recovery.img'
out_boot='build/phase1/recovery/extracted-phase1-boot.img'

test -s "$src_boot" || fail "missing $src_boot"
test -s "$src_ubi" || fail "missing $src_ubi"

./scripts/extract-ubi-volume.py --vol-id 0 --trim-android-bootimg "$src_ubi" "$out_boot"
cmp "$src_boot" "$out_boot" || fail 'extracted UBI volume does not match phase1 boot image'

printf 'UBI volume extraction smoke test passed: %s\n' "$out_boot"
