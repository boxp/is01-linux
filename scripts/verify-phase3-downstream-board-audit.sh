#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

summary='metadata/phase3-downstream-board-audit.md'
script='scripts/extract-phase3-downstream-board-info.sh'

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

[ -x "$script" ] || fail "extract script is missing or not executable: $script"
[ -f "$summary" ] || fail "summary is missing: $summary"

grep -F 'MACH_DECKARD`: `2008030`' "$summary" >/dev/null || fail 'summary does not record MACH_DECKARD 2008030'
grep -F 'downstream `.boot_params`: `0x20000100`' "$summary" >/dev/null || fail 'summary does not record downstream boot_params'
grep -F 'downstream `PHYS_OFFSET`: `0x20000000`' "$summary" >/dev/null || fail 'summary does not record PHYS_OFFSET'
grep -F 'mem=88M' "$summary" >/dev/null || fail 'summary does not record stock mem=88M cmdline'
grep -F 'ATAG-only boot' "$summary" >/dev/null || fail 'summary does not record next ATAG cut'

printf '%s\n' 'Phase 3 downstream board audit metadata verified'
