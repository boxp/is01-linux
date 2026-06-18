#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

url='http://ad-dl02.4sh.jp/developers/oss/is01/index_v2/download/bld010009/kernel.tar.gz'
sha='950adf03dc3db447c24c60109a20db4015941ed0bdb55b4941c2143665b415e4'
size='75951611'
archive='build/sources/is01-bld010009-kernel.tar.gz'
extract_dir='build/sources/kernel-bld010009'

mkdir -p build/sources

download_archive() {
  attempts=${SHARP_KERNEL_FETCH_ATTEMPTS:-5}
  attempt=1

  while [ "$attempt" -le "$attempts" ]; do
    printf 'Fetching Sharp kernel archive, attempt %s/%s...\n' "$attempt" "$attempts"
    if curl -fL --retry 3 --retry-delay 2 --retry-all-errors --connect-timeout 30 -C - -o "$archive" "$url"; then
      if printf '%s  %s\n' "$sha" "$archive" | sha256sum -c -; then
        return 0
      fi
      printf 'Checksum mismatch after download; removing archive before retry.\n' >&2
      rm -f "$archive"
    else
      printf 'Download attempt %s failed; retrying with resume if possible.\n' "$attempt" >&2
      if [ -f "$archive" ] && [ "$(wc -c <"$archive")" -ge "$size" ]; then
        printf 'Downloaded archive is already full-size but invalid; removing before retry.\n' >&2
        rm -f "$archive"
      fi
    fi

    attempt=$((attempt + 1))
    sleep 2
  done

  printf 'error: failed to fetch Sharp kernel archive after %s attempts.\n' "$attempts" >&2
  return 1
}

if [ -f "$archive" ] && printf '%s  %s\n' "$sha" "$archive" | sha256sum -c - >/dev/null 2>&1; then
  printf '%s  %s\n' "$sha" "$archive" | sha256sum -c -
else
  [ ! -f "$archive" ] || printf 'Existing Sharp kernel archive is incomplete or corrupt; retrying download.\n' >&2
  download_archive
fi

if [ ! -d "$extract_dir/kernel" ]; then
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"
  tar -xzf "$archive" -C "$extract_dir"
fi

test -f "$extract_dir/kernel/Makefile"
if [ ! -f "$extract_dir/kernel/.is01-patches-applied" ]; then
  for patch_file in patches/*.patch; do
    [ -f "$patch_file" ] || continue
    patch -d "$extract_dir/kernel" -p1 <"$patch_file"
  done
  touch "$extract_dir/kernel/.is01-patches-applied"
fi

printf 'Sharp kernel source is ready: %s\n' "$extract_dir/kernel"
