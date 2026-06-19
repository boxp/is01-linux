#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

buildroot_version=${BUILDROOT_VERSION:-2015.02}
buildroot_commit=${BUILDROOT_COMMIT:-6bf057b0f2ba188397a691f74877a4a30aaea3f9}
source_dir=${BUILDROOT_SRC:-build/sources/buildroot-$buildroot_version}
patch_dir="patches/buildroot-$buildroot_version"

link_project_board()
{
  mkdir -p "$source_dir/board"
  if [ -L "$source_dir/board/is01" ]; then
    rm -f "$source_dir/board/is01"
  elif [ -e "$source_dir/board/is01" ]; then
    printf 'error: %s already exists and is not a symlink\n' "$source_dir/board/is01" >&2
    exit 1
  fi
  ln -s "$repo_root/board/is01" "$source_dir/board/is01"
}

if [ -d "$source_dir/.git" ]; then
  current_commit=$(git -C "$source_dir" rev-parse HEAD)
  if [ "$current_commit" = "$buildroot_commit" ]; then
    if [ ! -f "$source_dir/.is01-patches-applied" ]; then
      for patch_file in "$patch_dir"/*.patch; do
        [ -f "$patch_file" ] || continue
        patch -d "$source_dir" -p1 <"$repo_root/$patch_file"
      done
      touch "$source_dir/.is01-patches-applied"
    fi
    link_project_board
    printf 'Buildroot source is ready: %s\n' "$source_dir"
    exit 0
  fi
  printf 'error: existing Buildroot source is at %s, expected %s\n' "$current_commit" "$buildroot_commit" >&2
  printf 'Remove %s or set BUILDROOT_SRC to another directory.\n' "$source_dir" >&2
  exit 1
fi

if [ -e "$source_dir" ]; then
  printf 'error: existing Buildroot source is not a git checkout: %s\n' "$source_dir" >&2
  printf 'Remove %s or set BUILDROOT_SRC to a prepared Buildroot git checkout.\n' "$source_dir" >&2
  exit 1
fi

mkdir -p "$(dirname "$source_dir")"
tmp_dir="$source_dir.tmp.$$"
rm -rf "$tmp_dir"
trap 'rm -rf "$tmp_dir"' EXIT INT TERM

git clone --depth 1 --branch "$buildroot_version" https://github.com/buildroot/buildroot.git "$tmp_dir"
current_commit=$(git -C "$tmp_dir" rev-parse HEAD)
[ "$current_commit" = "$buildroot_commit" ] || {
  printf 'error: Buildroot %s resolved to %s, expected %s\n' "$buildroot_version" "$current_commit" "$buildroot_commit" >&2
  exit 1
}

mv "$tmp_dir" "$source_dir"
for patch_file in "$patch_dir"/*.patch; do
  [ -f "$patch_file" ] || continue
  patch -d "$source_dir" -p1 <"$repo_root/$patch_file"
done
touch "$source_dir/.is01-patches-applied"
link_project_board
trap - EXIT INT TERM
printf 'Buildroot source is ready: %s\n' "$source_dir"
