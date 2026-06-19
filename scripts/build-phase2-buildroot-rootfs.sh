#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

buildroot_version=${BUILDROOT_VERSION:-2015.02}
buildroot_src=${BUILDROOT_SRC:-build/sources/buildroot-$buildroot_version}
out_dir=${PHASE2_BUILDROOT_OUT:-build/phase2/buildroot}
defconfig='configs/buildroot/is01_phase2_defconfig'
dl_dir=${BR2_DL_DIR:-$repo_root/build/sources/buildroot-dl}
jobs=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 2)}

./scripts/fetch-buildroot.sh
test -f "$buildroot_src/Makefile" || {
  printf 'error: missing prepared Buildroot source: %s\n' "$buildroot_src" >&2
  exit 1
}
test -f "$defconfig" || {
  printf 'error: missing %s\n' "$defconfig" >&2
  exit 1
}

mkdir -p "$out_dir" "$dl_dir"

make -C "$buildroot_src" O="$repo_root/$out_dir" BR2_DEFCONFIG="$repo_root/$defconfig" defconfig
make -C "$buildroot_src" O="$repo_root/$out_dir" BR2_DL_DIR="$dl_dir" -j"$jobs"

test -s "$out_dir/images/rootfs.cpio"
./scripts/verify-phase2-buildroot-rootfs.sh

printf 'Phase 2 Buildroot rootfs is ready:\n'
sha256sum "$out_dir/images/rootfs.cpio"
