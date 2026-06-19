#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

fragment='configs/mainline/is01_phase3.fragment'
dts='board/is01/phase3/qcom-qsd8x50-is01.dts'
fetch_script='scripts/fetch-mainline-kernel.sh'
build_script='scripts/build-phase3-mainline-boot.sh'

test -s "$fragment" || fail "missing $fragment"
test -s "$dts" || fail "missing $dts"
test -x "$fetch_script" || fail "$fetch_script is not executable"
test -x "$build_script" || fail "$build_script is not executable"

grep -F 'CONFIG_ARCH_QCOM=y' "$fragment" >/dev/null || fail 'mainline fragment does not enable ARCH_QCOM'
grep -F 'CONFIG_ARM_APPENDED_DTB=y' "$fragment" >/dev/null || fail 'mainline fragment does not enable appended DTB'
grep -F 'CONFIG_BLK_DEV_INITRD=y' "$fragment" >/dev/null || fail 'mainline fragment does not enable initrd'
grep -F 'CONFIG_PANIC_TIMEOUT=20' "$fragment" >/dev/null || fail 'mainline fragment does not set panic timeout'
grep -F 'rdinit=/init' "$fragment" >/dev/null || fail 'mainline fragment does not point to initramfs init'
grep -F 'qcom,qsd8x50' "$dts" >/dev/null || fail 'DTS does not identify QSD8x50'
grep -F 'panic=20' "$dts" >/dev/null || fail 'DTS does not carry non-UART reboot signal'
grep -F 'e998a232b9418db3301cb58468e291a4f41d6ab8306029b30d991f56251dc8d2' "$fetch_script" >/dev/null || fail 'mainline kernel checksum is not pinned'

if command -v dtc >/dev/null 2>&1; then
  mkdir -p build/phase3/config-check
  dtc -I dts -O dtb -o build/phase3/config-check/qcom-qsd8x50-is01.dtb "$dts"
fi

printf 'Phase 3 mainline config inputs verified.\n'
