#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

kernel="$tmp_dir/kernel.bin"
ramdisk="$tmp_dir/ramdisk.cpio"
second="$tmp_dir/second.dtb"
boot_img="$tmp_dir/test-boot.img"
second_boot_img="$tmp_dir/test-boot-second.img"
repacked_boot_img="$tmp_dir/test-boot-repacked.img"
json_out="$tmp_dir/test-boot.json"
second_json_out="$tmp_dir/test-boot-second.json"
repacked_json_out="$tmp_dir/test-boot-repacked.json"

printf 'kernel-test-payload' >"$kernel"
printf '070701ramdisk-test-payload' >"$ramdisk"
printf 'dtb-test-payload' >"$second"

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

./scripts/repack-android-bootimg.py \
  --source "$boot_img" \
  --kernel "$kernel" \
  --ramdisk "$ramdisk" \
  --cmdline 'console=ttyMSM2 androidboot.hardware=qcom' \
  --image-align-size 4096 \
  --output "$repacked_boot_img"

./scripts/inspect-android-bootimg.py --image-align-size 4096 --json "$repacked_boot_img" >"$repacked_json_out"

python3 - "$repacked_json_out" <<'PY'
import json
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text())
assert report["path"].endswith("test-boot-repacked.img")
assert report["kernel_size"] == len(b"kernel-test-payload")
assert report["ramdisk_size"] == len(b"070701ramdisk-test-payload")
assert report["cmdline"] == "console=ttyMSM2 androidboot.hardware=qcom"
assert report["image_align_size"] == 4096
PY

./scripts/mkbootimg.py \
  --kernel "$kernel" \
  --ramdisk "$ramdisk" \
  --second "$second" \
  --output "$second_boot_img" \
  --kernel-addr 0x20008000 \
  --ramdisk-addr 0x24000000 \
  --second-addr 0x20f00000 \
  --tags-addr 0x20000100 \
  --page-size 2048 \
  --image-align-size 4096 \
  --cmdline 'rdinit=/init panic=20 androidboot.hardware=qcom'

./scripts/inspect-android-bootimg.py --image-align-size 4096 --json "$second_boot_img" >"$second_json_out"

python3 - "$second_json_out" <<'PY'
import json
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text())
assert report["path"].endswith("test-boot-second.img")
assert report["second_size"] == len(b"dtb-test-payload")
assert report["second_addr"] == 0x20F00000
assert report["second_offset"] == 12288
assert report["dt_offset"] == 16384
assert report["image_size"] == 16384
PY

if ./scripts/inspect-android-bootimg.py --expect-page-size 4096 "$boot_img" >/dev/null 2>&1; then
  printf '%s\n' 'error: page-size mismatch was not detected' >&2
  exit 1
fi

printf '%s\n' 'Android boot image inspection tests passed'
