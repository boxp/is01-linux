#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

fragment='configs/mainline/is01_phase3.fragment'
lean_fragment='configs/mainline/is01_phase3_lean.fragment'
dts='board/is01/phase3/qcom-qsd8x50-is01.dts'
msm8660_timer_dts='board/is01/phase3/qcom-qsd8x50-is01-msm8660-timer.dts'
vic_timer_dts='board/is01/phase3/qcom-qsd8x50-is01-vic-timer.dts'
fetch_script='scripts/fetch-mainline-kernel.sh'
build_script='scripts/build-phase3-mainline-boot.sh'
lean_build_script='scripts/build-phase3-mainline-lean-boot.sh'

test -s "$fragment" || fail "missing $fragment"
test -s "$lean_fragment" || fail "missing $lean_fragment"
test -s "$dts" || fail "missing $dts"
test -s "$msm8660_timer_dts" || fail "missing $msm8660_timer_dts"
test -s "$vic_timer_dts" || fail "missing $vic_timer_dts"
test -x "$fetch_script" || fail "$fetch_script is not executable"
test -x "$build_script" || fail "$build_script is not executable"
test -x "$lean_build_script" || fail "$lean_build_script is not executable"

grep -F 'CONFIG_ARCH_QCOM=y' "$fragment" >/dev/null || fail 'mainline fragment does not enable ARCH_QCOM'
grep -F 'CONFIG_ARM_GIC=y' "$fragment" >/dev/null || fail 'mainline fragment does not enable ARM GIC'
grep -F 'CONFIG_ARM_VIC=y' "$fragment" >/dev/null || fail 'mainline fragment does not enable ARM VIC'
grep -F 'CONFIG_ARM_APPENDED_DTB=y' "$fragment" >/dev/null || fail 'mainline fragment does not enable appended DTB'
grep -F 'CONFIG_BLK_DEV_INITRD=y' "$fragment" >/dev/null || fail 'mainline fragment does not enable initrd'
grep -F 'CONFIG_CLKSRC_QCOM=y' "$fragment" >/dev/null || fail 'mainline fragment does not enable Qualcomm timer'
grep -F 'CONFIG_PANIC_TIMEOUT=20' "$fragment" >/dev/null || fail 'mainline fragment does not set panic timeout'
grep -F 'CONFIG_KERNEL_XZ=y' "$fragment" >/dev/null || fail 'mainline fragment does not request xz kernel compression'
grep -F 'rdinit=/init' "$fragment" >/dev/null || fail 'mainline fragment does not point to initramfs init'
grep -F 'CONFIG_ARCH_QCOM=y' "$lean_fragment" >/dev/null || fail 'lean mainline fragment does not enable ARCH_QCOM'
grep -F 'CONFIG_ARM_GIC=y' "$lean_fragment" >/dev/null || fail 'lean mainline fragment does not enable ARM GIC'
grep -F 'CONFIG_ARM_VIC=y' "$lean_fragment" >/dev/null || fail 'lean mainline fragment does not enable ARM VIC'
grep -F 'CONFIG_ARM_APPENDED_DTB=y' "$lean_fragment" >/dev/null || fail 'lean mainline fragment does not enable appended DTB'
grep -F 'CONFIG_CLKSRC_QCOM=y' "$lean_fragment" >/dev/null || fail 'lean mainline fragment does not enable Qualcomm timer'
grep -F 'CONFIG_CC_OPTIMIZE_FOR_SIZE=y' "$lean_fragment" >/dev/null || fail 'lean mainline fragment does not optimize for size'
grep -F '# CONFIG_NET is not set' "$lean_fragment" >/dev/null || fail 'lean mainline fragment must disable networking'
grep -F '# CONFIG_DRM is not set' "$lean_fragment" >/dev/null || fail 'lean mainline fragment must disable DRM'
grep -F 'qcom,qsd8x50' "$dts" >/dev/null || fail 'DTS does not identify QSD8x50'
grep -F 'panic=20' "$dts" >/dev/null || fail 'DTS does not carry non-UART reboot signal'
grep -F 'qcom,msm-8660-qgic' "$msm8660_timer_dts" >/dev/null || fail 'MSM8660 timer DTS does not include qgic'
grep -F 'qcom,scss-timer' "$msm8660_timer_dts" >/dev/null || fail 'MSM8660 timer DTS does not include scss timer'
grep -F 'arm,versatile-vic' "$vic_timer_dts" >/dev/null || fail 'VIC timer DTS does not include VIC'
grep -F '0xac100000' "$vic_timer_dts" >/dev/null || fail 'VIC timer DTS does not include QSD8x50 timer base'
grep -F 'e998a232b9418db3301cb58468e291a4f41d6ab8306029b30d991f56251dc8d2' "$fetch_script" >/dev/null || fail 'mainline kernel checksum is not pinned'

if command -v dtc >/dev/null 2>&1; then
  mkdir -p build/phase3/config-check
  dtc -I dts -O dtb -o build/phase3/config-check/qcom-qsd8x50-is01.dtb "$dts"
  dtc -I dts -O dtb -o build/phase3/config-check/qcom-qsd8x50-is01-msm8660-timer.dtb "$msm8660_timer_dts"
  dtc -I dts -O dtb -o build/phase3/config-check/qcom-qsd8x50-is01-vic-timer.dtb "$vic_timer_dts"
fi

printf 'Phase 3 mainline config inputs verified.\n'
