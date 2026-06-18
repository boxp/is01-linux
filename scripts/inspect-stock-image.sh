#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  printf 'usage: %s <mtd0-boot.img|mtd2-recovery.img>\n' "$0" >&2
  exit 2
fi

image=$1

test -f "$image" || {
  printf 'error: image not found: %s\n' "$image" >&2
  exit 1
}

printf 'file: %s\n' "$image"
file "$image"
printf 'size: '
wc -c <"$image"
printf 'sha256: '
sha256sum "$image" | awk '{print $1}'

if command -v ubireader_display_info >/dev/null 2>&1; then
  ubireader_display_info "$image"
else
  printf 'ubireader_display_info not found; install ubi_reader for detailed UBI inspection.\n'
fi
