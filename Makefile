SHELL := /bin/sh

.PHONY: help check lint test fmt phase1-fetch phase1-initramfs phase1-kernel phase1-recovery phase1-verify phase1-repack-stock-recovery phase1-repack-stock-verify phase1-stock-kernel-custom-initramfs-recovery phase1-stock-kernel-custom-initramfs-verify phase1-stock-kernel-raw-initramfs-recovery phase1-stock-kernel-raw-initramfs-verify phase2-initramfs phase2-initramfs-verify phase2-recovery phase2-verify phase2-buildroot-fetch phase2-buildroot-rootfs phase2-buildroot-rootfs-verify phase2-buildroot-recovery phase2-buildroot-recovery-verify phase3-mainline-fetch phase3-initramfs phase3-initramfs-verify phase3-mainline-config-verify phase3-mainline-boot phase3-mainline-boot-verify phase3-mainline-recovery phase3-mainline-boot-entry-probes phase3-mainline-boot-entry-probes-verify phase3-mainline-lean-boot phase3-mainline-lean-boot-verify phase3-mainline-lean-recovery phase3-mainline-dt-handoff-variants phase3-mainline-dt-handoff-variants-verify phase3-mainline-atag-dtb-placement-probes phase3-mainline-atag-dtb-placement-probes-verify phase3-early-payload-probes phase3-early-payload-probes-verify phase3-early-signal-probes phase3-early-signal-probes-verify phase3-display-independent-probes phase3-display-independent-probes-verify phase3-stock-header-kernel-swap-probes phase3-stock-header-kernel-swap-probes-verify phase3-stock-header-linux-entry phase3-stock-header-linux-entry-verify phase3-stock-header-dtb-handoff phase3-stock-header-dtb-handoff-verify phase3-decompressor-entry-reset phase3-decompressor-entry-reset-verify phase3-decompressor-pre-kernel-reset phase3-decompressor-pre-kernel-reset-verify phase3-downstream-board-audit phase3-downstream-board-audit-verify

help:
	@printf '%s\n' \
		'Targets:' \
		'  make check  Run repository checks' \
		'  make lint   Run lint checks' \
		'  make fmt    Format files when formatters are available' \
		'  make phase1-fetch      Fetch Phase 1 source/toolchain inputs' \
		'  make phase1-initramfs  Build the minimal Phase 1 initramfs' \
		'  make phase1-kernel     Build the Sharp downstream kernel' \
		'  make phase1-recovery   Build the manual-test recovery candidate' \
		'  make phase1-verify     Verify generated Phase 1 artifacts' \
		'  make phase1-repack-stock-recovery  Repack stock recovery without changing boot payload' \
		'  make phase1-repack-stock-verify    Verify stock recovery repack artifacts' \
		'  make phase1-stock-kernel-custom-initramfs-recovery  Build stock-kernel/custom-initramfs recovery candidate' \
		'  make phase1-stock-kernel-custom-initramfs-verify    Verify stock-kernel/custom-initramfs artifacts' \
		'  make phase1-stock-kernel-raw-initramfs-recovery  Build stock-kernel/raw-initramfs recovery candidate' \
		'  make phase1-stock-kernel-raw-initramfs-verify    Verify stock-kernel/raw-initramfs artifacts' \
		'  make phase2-initramfs  Build the Phase 2 minimal userspace initramfs' \
		'  make phase2-initramfs-verify  Verify Phase 2 initramfs contents' \
		'  make phase2-recovery  Build the Phase 2 manual-test recovery candidate' \
		'  make phase2-verify    Verify generated Phase 2 artifacts' \
		'  make phase2-buildroot-fetch  Fetch pinned Buildroot source' \
		'  make phase2-buildroot-rootfs  Build the Phase 2 BusyBox/Dropbear rootfs' \
		'  make phase2-buildroot-rootfs-verify  Verify Phase 2 Buildroot rootfs' \
		'  make phase2-buildroot-recovery  Build the Phase 2 Buildroot recovery candidate' \
		'  make phase2-buildroot-recovery-verify  Verify Phase 2 Buildroot recovery artifacts' \
		'  make phase3-mainline-fetch  Fetch pinned mainline Linux source' \
		'  make phase3-initramfs  Build the Phase 3 reboot-signal initramfs' \
		'  make phase3-initramfs-verify  Verify Phase 3 initramfs contents' \
		'  make phase3-mainline-config-verify  Verify Phase 3 mainline config inputs' \
		'  make phase3-mainline-boot  Build the Phase 3 mainline Android boot payload' \
		'  make phase3-mainline-boot-verify  Verify Phase 3 mainline boot payload' \
		'  make phase3-mainline-recovery  Build the Phase 3 manual-test recovery candidate' \
		'  make phase3-mainline-boot-entry-probes  Build Phase 3 boot-entry recovery probe candidates' \
		'  make phase3-mainline-boot-entry-probes-verify  Verify Phase 3 boot-entry probe candidates' \
		'  make phase3-mainline-lean-boot  Build the Phase 3 lean mainline boot payload' \
		'  make phase3-mainline-lean-boot-verify  Verify the Phase 3 lean mainline boot payload' \
		'  make phase3-mainline-lean-recovery  Build the Phase 3 lean recovery candidate' \
		'  make phase3-mainline-dt-handoff-variants  Build Phase 3 DT handoff recovery candidates' \
		'  make phase3-mainline-dt-handoff-variants-verify  Verify Phase 3 DT handoff candidates' \
		'  make phase3-mainline-atag-dtb-placement-probes  Build Phase 3 ATAG/DTB placement recovery candidates' \
		'  make phase3-mainline-atag-dtb-placement-probes-verify  Verify Phase 3 ATAG/DTB placement candidates' \
		'  make phase3-early-payload-probes  Build Phase 3 non-Linux early payload candidates' \
		'  make phase3-early-payload-probes-verify  Verify Phase 3 non-Linux early payload candidates' \
		'  make phase3-early-signal-probes  Build Phase 3 Image/zImage-shaped early signal candidates' \
		'  make phase3-early-signal-probes-verify  Verify Phase 3 Image/zImage-shaped early signal candidates' \
		'  make phase3-display-independent-probes  Build Phase 3 display-independent early signal candidates' \
		'  make phase3-display-independent-probes-verify  Verify Phase 3 display-independent early signal candidates' \
		'  make phase3-stock-header-kernel-swap-probes  Build Phase 3 stock-header kernel-swap candidates' \
		'  make phase3-stock-header-kernel-swap-probes-verify  Verify Phase 3 stock-header kernel-swap candidates' \
		'  make phase3-stock-header-linux-entry  Build Phase 3 stock-header Linux entry candidates' \
		'  make phase3-stock-header-linux-entry-verify  Verify Phase 3 stock-header Linux entry candidates' \
		'  make phase3-stock-header-dtb-handoff  Build Phase 3 stock-header DTB handoff candidates' \
		'  make phase3-stock-header-dtb-handoff-verify  Verify Phase 3 stock-header DTB handoff candidates' \
		'  make phase3-decompressor-entry-reset  Build Phase 3 decompressor entry reset candidate' \
		'  make phase3-decompressor-entry-reset-verify  Verify Phase 3 decompressor entry reset candidate' \
		'  make phase3-decompressor-pre-kernel-reset  Build Phase 3 pre-decompress_kernel reset candidate' \
		'  make phase3-decompressor-pre-kernel-reset-verify  Verify Phase 3 pre-decompress_kernel reset candidate' \
		'  make phase3-downstream-board-audit  Extract downstream board handoff facts' \
		'  make phase3-downstream-board-audit-verify  Verify downstream board audit metadata'

check: lint test

lint:
	@./ci/check.sh

test:
	@./scripts/test-android-bootimg-inspect.sh

fmt:
	@if command -v shfmt >/dev/null 2>&1; then \
		find ci scripts -type f -name '*.sh' -print 2>/dev/null | xargs -r shfmt -w; \
	else \
		printf '%s\n' 'shfmt not found; skipping shell formatting'; \
	fi

phase1-fetch:
	@./scripts/fetch-sharp-kernel.sh
	@./scripts/fetch-android-toolchain.sh

phase1-initramfs:
	@./scripts/build-phase1-initramfs.sh

phase1-kernel:
	@./scripts/build-phase1-kernel.sh

phase1-recovery:
	@./scripts/build-phase1-recovery-image.sh

phase1-verify:
	@./scripts/verify-phase1-artifacts.sh

phase1-repack-stock-recovery:
	@./scripts/build-phase1-repack-stock-recovery.sh

phase1-repack-stock-verify:
	@./scripts/verify-phase1-repack-stock.sh

phase1-stock-kernel-custom-initramfs-recovery:
	@./scripts/build-phase1-stock-kernel-custom-initramfs-recovery.sh

phase1-stock-kernel-custom-initramfs-verify:
	@./scripts/verify-phase1-stock-kernel-custom-initramfs.sh

phase1-stock-kernel-raw-initramfs-recovery:
	@./scripts/build-phase1-stock-kernel-raw-initramfs-recovery.sh

phase1-stock-kernel-raw-initramfs-verify:
	@./scripts/verify-phase1-stock-kernel-raw-initramfs.sh

phase2-initramfs:
	@./scripts/build-phase2-initramfs.sh

phase2-initramfs-verify:
	@./scripts/verify-phase2-initramfs.sh

phase2-recovery:
	@./scripts/build-phase2-recovery.sh

phase2-verify:
	@./scripts/verify-phase2-artifacts.sh

phase2-buildroot-fetch:
	@./scripts/fetch-buildroot.sh

phase2-buildroot-rootfs:
	@./scripts/build-phase2-buildroot-rootfs.sh

phase2-buildroot-rootfs-verify:
	@./scripts/verify-phase2-buildroot-rootfs.sh

phase2-buildroot-recovery:
	@./scripts/build-phase2-buildroot-recovery.sh

phase2-buildroot-recovery-verify:
	@./scripts/verify-phase2-buildroot-recovery.sh

phase3-mainline-fetch:
	@./scripts/fetch-mainline-kernel.sh

phase3-initramfs:
	@./scripts/build-phase3-initramfs.sh

phase3-initramfs-verify:
	@./scripts/verify-phase3-initramfs.sh

phase3-mainline-config-verify:
	@./scripts/verify-phase3-mainline-config.sh

phase3-mainline-boot:
	@./scripts/build-phase3-mainline-boot.sh

phase3-mainline-boot-verify:
	@./scripts/verify-phase3-mainline-boot.sh

phase3-mainline-recovery:
	@./scripts/build-phase3-mainline-recovery.sh

phase3-mainline-boot-entry-probes:
	@./scripts/build-phase3-mainline-boot-entry-probes.sh

phase3-mainline-boot-entry-probes-verify:
	@./scripts/verify-phase3-mainline-boot-entry-probes.sh

phase3-mainline-lean-boot:
	@./scripts/build-phase3-mainline-lean-boot.sh

phase3-mainline-lean-boot-verify:
	@./scripts/verify-phase3-mainline-lean-boot.sh

phase3-mainline-lean-recovery:
	@./scripts/build-phase3-mainline-lean-recovery.sh

phase3-mainline-dt-handoff-variants:
	@./scripts/build-phase3-mainline-dt-handoff-variants.sh

phase3-mainline-dt-handoff-variants-verify:
	@./scripts/verify-phase3-mainline-dt-handoff-variants.sh

phase3-mainline-atag-dtb-placement-probes:
	@./scripts/build-phase3-mainline-atag-dtb-placement-probes.sh

phase3-mainline-atag-dtb-placement-probes-verify:
	@./scripts/verify-phase3-mainline-atag-dtb-placement-probes.sh

phase3-early-payload-probes:
	@./scripts/build-phase3-early-payload-probes.sh

phase3-early-payload-probes-verify:
	@./scripts/verify-phase3-early-payload-probes.sh

phase3-early-signal-probes:
	@./scripts/build-phase3-early-signal-probes.sh

phase3-early-signal-probes-verify:
	@./scripts/verify-phase3-early-signal-probes.sh

phase3-display-independent-probes:
	@./scripts/build-phase3-display-independent-probes.sh

phase3-display-independent-probes-verify:
	@./scripts/verify-phase3-display-independent-probes.sh

phase3-stock-header-kernel-swap-probes:
	@./scripts/build-phase3-stock-header-kernel-swap-probes.sh

phase3-stock-header-kernel-swap-probes-verify:
	@./scripts/verify-phase3-stock-header-kernel-swap-probes.sh

phase3-stock-header-linux-entry:
	@./scripts/build-phase3-stock-header-linux-entry.sh

phase3-stock-header-linux-entry-verify:
	@./scripts/verify-phase3-stock-header-linux-entry.sh

phase3-stock-header-dtb-handoff:
	@./scripts/build-phase3-stock-header-dtb-handoff.sh

phase3-stock-header-dtb-handoff-verify:
	@./scripts/verify-phase3-stock-header-dtb-handoff.sh

phase3-decompressor-entry-reset:
	@./scripts/build-phase3-decompressor-entry-reset.sh

phase3-decompressor-entry-reset-verify:
	@./scripts/verify-phase3-decompressor-entry-reset.sh

phase3-decompressor-pre-kernel-reset:
	@./scripts/build-phase3-decompressor-pre-kernel-reset.sh

phase3-decompressor-pre-kernel-reset-verify:
	@./scripts/verify-phase3-decompressor-pre-kernel-reset.sh

phase3-downstream-board-audit:
	@./scripts/extract-phase3-downstream-board-info.sh

phase3-downstream-board-audit-verify:
	@./scripts/verify-phase3-downstream-board-audit.sh
