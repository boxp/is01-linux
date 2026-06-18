#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

toolchain_dir='build/toolchains/arm-eabi-4.6'
toolchain_url='https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-eabi-4.6'
toolchain_ref='b4ecd7806d8f46cddeacaf9f8de92c191fb266e4'

mkdir -p build/toolchains

if [ ! -d "$toolchain_dir/.git" ]; then
  git clone --no-checkout "$toolchain_url" "$toolchain_dir"
fi

git -c safe.directory="$repo_root/$toolchain_dir" -C "$toolchain_dir" fetch --depth 1 origin "$toolchain_ref"
git -c safe.directory="$repo_root/$toolchain_dir" -C "$toolchain_dir" checkout --detach "$toolchain_ref"

test -x "$toolchain_dir/bin/arm-eabi-gcc"

if ! "$toolchain_dir/bin/arm-eabi-gcc" --version >/dev/null 2>&1; then
  cat >&2 <<'EOF'
error: arm-eabi-gcc exists but cannot run.
The AOSP arm-eabi-4.6 toolchain is a 32-bit Linux binary.
Install 32-bit runtime libraries before building:

  sudo apt-get update
  sudo apt-get install -y libc6-i386 lib32z1
EOF
  exit 1
fi

"$toolchain_dir/bin/arm-eabi-gcc" --version | head -1
