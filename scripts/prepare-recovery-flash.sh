#!/bin/sh
set -eu

# PHASE1_MANUAL_FLASH_ONLY
# This helper intentionally does not run adb, flash_image, dd, or any device write.

if [ "$#" -ne 1 ]; then
  printf 'usage: %s <candidate-recovery-image>\n' "$0" >&2
  exit 2
fi

image=$1
test -f "$image" || {
  printf 'error: image not found: %s\n' "$image" >&2
  exit 1
}

sha=$(sha256sum "$image" | awk '{print $1}')
size=$(wc -c <"$image")

cat <<EOF
Manual recovery flash checklist
===============================

Candidate image:
  path: $image
  size: $size
  sha256: $sha

Codex/repo boundary:
  This script does not write to the IS01.
  A human must copy and execute commands manually after confirming the checklist.

Before writing:
  [ ] target partition is recovery
  [ ] stock mtd2-recovery.img backup is available
  [ ] stock recovery sha256 has been checked against the manifest
  [ ] candidate image sha256 above is recorded
  [ ] battery and USB/ADB connection are stable
  [ ] restore command is ready in another terminal

Manual write command template:

  adb push '$image' /sdcard/is01-restore/phase1-recovery.img
  printf '/system/bin/flash_image recovery /sdcard/is01-restore/phase1-recovery.img\\nexit\\n' | adb shell /sbin/au

Manual stock restore template:

  adb push mtd2-recovery.img /sdcard/is01-restore/mtd2-recovery.img
  printf '/system/bin/flash_image recovery /sdcard/is01-restore/mtd2-recovery.img\\nexit\\n' | adb shell /sbin/au
EOF
