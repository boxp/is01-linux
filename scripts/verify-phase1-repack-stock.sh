#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

out_dir='build/phase1/repack-stock'
stock_boot="$out_dir/stock-recovery-boot.img"
ubi_payload="$out_dir/stock-recovery-volume.bin"
recovery_img="$out_dir/phase1-stock-repack-recovery.img"
roundtrip_volume="$out_dir/roundtrip-stock-recovery-volume.bin"
roundtrip_boot="$out_dir/roundtrip-stock-recovery-boot.img"
partition_size=11534336

test -s "$stock_boot" || fail "missing $stock_boot"
test -s "$ubi_payload" || fail "missing $ubi_payload"
test -s "$recovery_img" || fail "missing $recovery_img"

file "$stock_boot" | grep 'Android bootimg' >/dev/null || fail 'stock recovery boot image is not an Android bootimg'
file "$recovery_img" | grep 'UBI image' >/dev/null || fail 'repacked recovery image is not a UBI image'
[ "$(wc -c <"$recovery_img")" -eq "$partition_size" ] || fail 'repacked recovery image size does not match mtd2'
[ "$(wc -c <"$ubi_payload")" -eq 9547776 ] || fail 'stock recovery UBI volume payload size does not match stock recovery'
./scripts/check-ubi-layout.py --expect-vid-offset 256 --expect-data-offset 2048 --expect-pebs 76 "$recovery_img"

./scripts/extract-ubi-volume.py --vol-id 0 "$recovery_img" "$roundtrip_volume"
cmp "$ubi_payload" "$roundtrip_volume" || fail 'repacked UBI volume does not round-trip to stock volume'
./scripts/extract-ubi-volume.py --vol-id 0 --trim-android-bootimg "$recovery_img" "$roundtrip_boot"
cmp "$stock_boot" "$roundtrip_boot" || fail 'repacked UBI volume does not round-trip to stock boot image'

sha256sum "$stock_boot" "$ubi_payload" "$recovery_img" "$roundtrip_volume" "$roundtrip_boot" >"$out_dir/SHA256SUMS"

printf 'Phase 1 stock recovery repack artifacts verified:\n'
cat "$out_dir/SHA256SUMS"
