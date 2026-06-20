#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

kernel="$tmp_dir/kernel.bin"
ramdisk="$tmp_dir/ramdisk.cpio"
boot_img="$tmp_dir/test-boot.img"
json_out="$tmp_dir/test-boot.json"

printf 'kernel-test-payload' >"$kernel"
printf '070701ramdisk-test-payload' >"$ramdisk"

./scripts/mkbootimg.py \
  --kernel "$kernel" \
  --ramdisk "$ramdisk" \
  --output "$boot_img" \
  --kernel-addr 0x20008000 \
  --ramdisk-addr 0x24000000 \
  --second-addr 0x20f00000 \
  --tags-addr 0x20000100 \
  --page-size 2048 \
  --image-align-size 4096 \
  --cmdline 'rdinit=/init panic=20 androidboot.hardware=qcom'

./scripts/inspect-android-bootimg.py --image-align-size 4096 --json "$boot_img" >"$json_out"

python3 - "$json_out" <<'PY'
import json
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text())
assert report["path"].endswith("test-boot.img")
assert report["kernel_size"] == len(b"kernel-test-payload")
assert report["ramdisk_size"] == len(b"070701ramdisk-test-payload")
assert report["page_size"] == 2048
assert report["image_align_size"] == 4096
assert report["kernel_offset"] == 4096
assert report["ramdisk_offset"] == 8192
assert report["image_size"] == 12288
assert report["cmdline"] == "rdinit=/init panic=20 androidboot.hardware=qcom"
PY

./scripts/inspect-android-bootimg.py "$boot_img" | grep -F 'kernel_addr: 0x20008000' >/dev/null
./scripts/inspect-android-bootimg.py --image-align-size 4096 --expect-page-size 2048 --expect-align-size 4096 "$boot_img" >/dev/null

if ./scripts/inspect-android-bootimg.py --expect-page-size 4096 "$boot_img" >/dev/null 2>&1; then
  printf '%s\n' 'error: page-size mismatch was not detected' >&2
  exit 1
fi

printf '%s\n' 'Android boot image inspection tests passed'
