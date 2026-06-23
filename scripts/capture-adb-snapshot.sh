#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

label=${1:-manual}
out_root=${IS01_SNAPSHOT_DIR:-build/device-snapshots}
timeout_seconds=${ADB_TIMEOUT_SECONDS:-30}
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
safe_label=$(printf '%s' "$label" | tr -c 'A-Za-z0-9._-' '_')
out_dir="$out_root/${timestamp}-${safe_label}"

command -v adb >/dev/null 2>&1 || {
  printf 'error: adb not found\n' >&2
  exit 1
}

mkdir -p "$out_dir"

run_host() {
  name=$1
  shift
  {
    printf '$'
    printf ' %s' "$@"
    printf '\n'
    "$@"
  } >"$out_dir/$name" 2>&1 || {
    status=$?
    printf 'command failed with exit status %s\n' "$status" >>"$out_dir/$name"
    return 0
  }
}

run_adb_shell() {
  name=$1
  shift
  command_text=$*
  {
    printf '$ adb shell %s\n' "$command_text"
    if command -v timeout >/dev/null 2>&1; then
      timeout "$timeout_seconds" adb shell "$command_text"
    else
      adb shell "$command_text"
    fi
  } >"$out_dir/$name" 2>&1 || {
    status=$?
    printf 'command failed with exit status %s\n' "$status" >>"$out_dir/$name"
    return 0
  }
}

cat >"$out_dir/README.txt" <<EOF
IS01 ADB snapshot
=================

label: $label
timestamp_utc: $timestamp
timeout_seconds: $timeout_seconds

This snapshot is read-only from the device perspective. It collects host-side
ADB state plus text diagnostics exposed by the currently booted stock or
recovery environment. Generated snapshots may contain device-specific or
personal data and should not be committed.
EOF

run_host host-date.txt date -u '+%Y-%m-%dT%H:%M:%SZ'
run_host adb-devices.txt adb devices -l

run_adb_shell getprop.txt getprop
run_adb_shell proc-cmdline.txt cat /proc/cmdline
run_adb_shell proc-mtd.txt cat /proc/mtd
run_adb_shell proc-mounts.txt cat /proc/mounts
run_adb_shell proc-partitions.txt cat /proc/partitions
run_adb_shell proc-meminfo.txt cat /proc/meminfo
run_adb_shell proc-iomem.txt cat /proc/iomem
run_adb_shell dmesg.txt dmesg
run_adb_shell logcat-main.txt logcat -d -v time
run_adb_shell logcat-radio.txt logcat -b radio -d -v time
run_adb_shell dev-mtd-ls.txt ls -l /dev/mtd
run_adb_shell dev-block-ls.txt ls -l /dev/block
run_adb_shell sdcard-phase3-ls.txt ls -l /sdcard/is01-phase3-probes
run_adb_shell android-usb-state.txt cat /sys/class/android_usb/android0/state

(
  cd "$out_dir"
  find . -type f ! -name SHA256SUMS -exec sha256sum {} + |
    sed 's#  \./#  #' >SHA256SUMS
)

printf 'IS01 ADB snapshot written to %s\n' "$out_dir"
