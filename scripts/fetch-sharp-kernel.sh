#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

url='http://ad-dl02.4sh.jp/developers/oss/is01/index_v2/download/bld010009/kernel.tar.gz'
sha='950adf03dc3db447c24c60109a20db4015941ed0bdb55b4941c2143665b415e4'
archive='build/sources/is01-bld010009-kernel.tar.gz'
extract_dir='build/sources/kernel-bld010009'

mkdir -p build/sources

if [ ! -f "$archive" ]; then
  curl -fL -o "$archive" "$url"
fi

printf '%s  %s\n' "$sha" "$archive" | sha256sum -c -

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
