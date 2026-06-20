# Phase 3 downstream board audit

Generated from Sharp IS01 BLD010009 downstream kernel source. This summary records boot-handoff facts used to guide Phase 3 mainline bring-up without copying the downstream board file wholesale.

## Inputs

- kernel source: `build/sources/kernel-bld010009/kernel`
- board file: `arch/arm/mach-msm/board-deckard.c`
- mach-types: `arch/arm/tools/mach-types`
- stock config: `configs/is01-stock.config`

## Machine identity

- downstream board: `DECKARD` / `SHARP DECKARD`
- `MACH_DECKARD`: `2008030`
- related `MACH_QSD8X50_COMET`: `1008001`
- `MACHINE_START(DECKARD)` line: `2675`

## Boot handoff facts

- downstream `.boot_params`: `0x20000100`
- stock Android boot image tags address: `0x20000100`
- downstream `PHYS_OFFSET`: `0x20000000`
- stock cmdline: `"init=/sbin/init root=/dev/ram rw initrd=0x11000000,16M console=ttyDCC0 mem=88M"`

## Phase 3 implication

- The Phase 3 boot image already uses kernel address `0x20008000` and tags address `0x20000100`, matching the downstream handoff values.
- The current Phase 3 DTS memory node uses `0x20000000` + `0x05800000`, matching stock `PHYS_OFFSET` and `mem=88M` from the stock cmdline.
- Since baseline, boot-entry probes, and lean mainline candidates all stop before the timed reboot signal, the next variants should test machine/DT handoff assumptions rather than Android boot header cmdline/page alignment.
- Candidate next cuts: ATAG-only boot, alternate appended-DTB placement/compatibility, or a custom early-entry payload with an external signal.

## Extracted evidence files

- `build/phase3/downstream-board-audit/deckard-machine-start.txt`
- `build/phase3/downstream-board-audit/stock-config-board-lines.txt`
- `build/phase3/downstream-board-audit/mach-types-lines.txt`
- `build/phase3/downstream-board-audit/kconfig-board-lines.txt`
- `build/phase3/downstream-board-audit/makefile-board-lines.txt`
- `build/phase3/downstream-board-audit/deckard-memory-reservations.txt`
