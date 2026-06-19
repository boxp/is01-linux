SHELL := /bin/sh

.PHONY: help check lint fmt phase1-fetch phase1-initramfs phase1-kernel phase1-recovery phase1-verify phase1-repack-stock-recovery phase1-repack-stock-verify phase1-stock-kernel-custom-initramfs-recovery phase1-stock-kernel-custom-initramfs-verify phase1-stock-kernel-raw-initramfs-recovery phase1-stock-kernel-raw-initramfs-verify phase2-initramfs phase2-initramfs-verify phase2-recovery phase2-verify

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
		'  make phase2-verify    Verify generated Phase 2 artifacts'

check: lint

lint:
	@./ci/check.sh

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
