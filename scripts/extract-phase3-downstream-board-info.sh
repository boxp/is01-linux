#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

kernel_src=${KERNEL_SRC:-build/sources/kernel-bld010009/kernel}
out_dir=${PHASE3_DOWNSTREAM_BOARD_AUDIT_OUT:-build/phase3/downstream-board-audit}
summary=${PHASE3_DOWNSTREAM_BOARD_AUDIT_SUMMARY:-metadata/phase3-downstream-board-audit.md}

if [ ! -d "$kernel_src" ]; then
  ./scripts/fetch-sharp-kernel.sh
fi

board="$kernel_src/arch/arm/mach-msm/board-deckard.c"
mach_types="$kernel_src/arch/arm/tools/mach-types"
mach_kconfig="$kernel_src/arch/arm/mach-msm/Kconfig"
mach_makefile="$kernel_src/arch/arm/mach-msm/Makefile"
memory_h="$kernel_src/arch/arm/mach-msm/include/mach/memory.h"
stock_config='configs/is01-stock.config'

for path in "$board" "$mach_types" "$mach_kconfig" "$mach_makefile" "$memory_h" "$stock_config"; do
  [ -f "$path" ] || {
    printf 'error: required input is missing: %s\n' "$path" >&2
    exit 1
  }
done

mkdir -p "$out_dir" "$(dirname -- "$summary")"

deckard_mach_line=$(awk '$1 == "deckard" { print; found=1 } END { exit found ? 0 : 1 }' "$mach_types")
comet_mach_line=$(awk '$1 == "qsd8x50_comet" { print; found=1 } END { exit found ? 0 : 1 }' "$mach_types")
deckard_mach_id=$(printf '%s\n' "$deckard_mach_line" | awk '{ print $4 }')
comet_mach_id=$(printf '%s\n' "$comet_mach_line" | awk '{ print $4 }')
deckard_board_line=$(grep -n 'MACHINE_START(DECKARD' "$board" | head -n 1 | cut -d: -f1)
boot_params_line=$(grep -n 'boot_params[[:space:]]*=' "$board" | tail -n 1)
boot_params=$(printf '%s\n' "$boot_params_line" | awk -F'[=,]' '{ gsub(/[[:space:]]/, "", $2); print $2 }')
phys_offset_line=$(grep -n 'PHYS_OFFSET.*0x20000000' "$memory_h" | head -n 1)
stock_cmdline=$(grep '^CONFIG_CMDLINE=' "$stock_config" | sed 's/^CONFIG_CMDLINE=//')

awk '
  /MACHINE_START\(DECKARD/ { in_block=1 }
  in_block { print }
  in_block && /MACHINE_END/ { exit }
' "$board" >"$out_dir/deckard-machine-start.txt"

grep -nE 'CONFIG_ARCH_QSD8X50|CONFIG_MACH_QSD8X50_COMET|CONFIG_MACH_DECKARD|CONFIG_CMDLINE=' "$stock_config" \
  >"$out_dir/stock-config-board-lines.txt"

grep -nE 'MACH_DECKARD|MACH_QSD8X50_COMET' "$mach_types" \
  >"$out_dir/mach-types-lines.txt"

grep -nE 'MACH_DECKARD|MACH_QSD8X50_COMET' "$mach_kconfig" \
  >"$out_dir/kconfig-board-lines.txt"

grep -nE 'board-deckard|board-comet' "$mach_makefile" \
  >"$out_dir/makefile-board-lines.txt"

grep -nE 'PMEM|MSM_FB_SIZE|MSM_SMI_|MSM_FB_BASE|MSM_GPU_PHYS|MSM_AUDIO_SIZE' "$board" \
  >"$out_dir/deckard-memory-reservations.txt"

{
  printf '# Phase 3 downstream board audit\n\n'
  printf 'Generated from Sharp IS01 BLD010009 downstream kernel source. This summary records boot-handoff facts used to guide Phase 3 mainline bring-up without copying the downstream board file wholesale.\n\n'
  printf '## Inputs\n\n'
  printf -- '- kernel source: `%s`\n' "$kernel_src"
  printf -- '- board file: `arch/arm/mach-msm/board-deckard.c`\n'
  printf -- '- mach-types: `arch/arm/tools/mach-types`\n'
  printf -- '- stock config: `%s`\n\n' "$stock_config"
  printf '## Machine identity\n\n'
  printf -- '- downstream board: `DECKARD` / `SHARP DECKARD`\n'
  printf -- '- `MACH_DECKARD`: `%s`\n' "$deckard_mach_id"
  printf -- '- related `MACH_QSD8X50_COMET`: `%s`\n' "$comet_mach_id"
  printf -- '- `MACHINE_START(DECKARD)` line: `%s`\n\n' "$deckard_board_line"
  printf '## Boot handoff facts\n\n'
  printf -- '- downstream `.boot_params`: `%s`\n' "$boot_params"
  printf -- '- stock Android boot image tags address: `0x20000100`\n'
  printf -- '- downstream `PHYS_OFFSET`: `0x20000000`\n'
  printf -- '- stock cmdline: `%s`\n\n' "$stock_cmdline"
  printf '## Phase 3 implication\n\n'
  printf -- '- The Phase 3 boot image already uses kernel address `0x20008000` and tags address `0x20000100`, matching the downstream handoff values.\n'
  printf -- '- The current Phase 3 DTS memory node uses `0x20000000` + `0x05800000`, matching stock `PHYS_OFFSET` and `mem=88M` from the stock cmdline.\n'
  printf -- '- Since baseline, boot-entry probes, and lean mainline candidates all stop before the timed reboot signal, the next variants should test machine/DT handoff assumptions rather than Android boot header cmdline/page alignment.\n'
  printf -- '- Candidate next cuts: ATAG-only boot, alternate appended-DTB placement/compatibility, or a custom early-entry payload with an external signal.\n\n'
  printf '## Extracted evidence files\n\n'
  printf -- '- `%s/deckard-machine-start.txt`\n' "$out_dir"
  printf -- '- `%s/stock-config-board-lines.txt`\n' "$out_dir"
  printf -- '- `%s/mach-types-lines.txt`\n' "$out_dir"
  printf -- '- `%s/kconfig-board-lines.txt`\n' "$out_dir"
  printf -- '- `%s/makefile-board-lines.txt`\n' "$out_dir"
  printf -- '- `%s/deckard-memory-reservations.txt`\n' "$out_dir"
} >"$summary"

cat >"$out_dir/values.env" <<EOF
DECKARD_MACH_ID=$deckard_mach_id
QSD8X50_COMET_MACH_ID=$comet_mach_id
DECKARD_BOOT_PARAMS=$boot_params
DECKARD_PHYS_OFFSET=0x20000000
EOF

printf 'Phase 3 downstream board audit is ready:\n'
printf '  %s\n' "$summary"
printf '  %s\n' "$out_dir"
