SHELL := /bin/sh

.PHONY: help check lint fmt phase1-fetch phase1-initramfs phase1-kernel phase1-recovery phase1-verify

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
		'  make phase1-verify     Verify generated Phase 1 artifacts'

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
