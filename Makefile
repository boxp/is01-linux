SHELL := /bin/sh

.PHONY: help check lint fmt

help:
	@printf '%s\n' \
		'Targets:' \
		'  make check  Run repository checks' \
		'  make lint   Run lint checks' \
		'  make fmt    Format files when formatters are available'

check: lint

lint:
	@./ci/check.sh

fmt:
	@if command -v shfmt >/dev/null 2>&1; then \
		find ci scripts -type f -name '*.sh' -print 2>/dev/null | xargs -r shfmt -w; \
	else \
		printf '%s\n' 'shfmt not found; skipping shell formatting'; \
	fi

