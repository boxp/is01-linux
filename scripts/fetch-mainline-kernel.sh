#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

version=${MAINLINE_KERNEL_VERSION:-6.12.94}
archive="linux-$version.tar.xz"
url=${MAINLINE_KERNEL_URL:-https://cdn.kernel.org/pub/linux/kernel/v6.x/$archive}
expected_sha256=${MAINLINE_KERNEL_SHA256:-e998a232b9418db3301cb58468e291a4f41d6ab8306029b30d991f56251dc8d2}

sources_dir='build/sources'
archive_path="$sources_dir/$archive"
extract_dir="$sources_dir/linux-$version"

mkdir -p "$sources_dir"

if [ ! -s "$archive_path" ]; then
  command -v wget >/dev/null 2>&1 || {
    printf 'error: wget not found\n' >&2
    exit 1
  }
  wget -O "$archive_path.tmp" "$url"
  mv "$archive_path.tmp" "$archive_path"
fi

printf '%s  %s\n' "$expected_sha256" "$archive_path" | sha256sum -c -

if [ ! -d "$extract_dir" ]; then
  tar -C "$sources_dir" -xf "$archive_path"
fi

printf 'Mainline kernel source is ready:\n'
printf '  version: %s\n' "$version"
printf '  source:  %s\n' "$extract_dir"
