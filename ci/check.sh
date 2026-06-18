#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

for path in README.md AGENTS.md Makefile .github/workflows/ci.yml; do
  [ -f "$path" ] || fail "required file is missing: $path"
done

committable_files=$(git ls-files --cached --others --exclude-standard)

if printf '%s\n' "$committable_files" | grep -E '\.sh$' | while IFS= read -r script; do sh -n "$script" || exit 1; done; then
  :
else
  fail "shell syntax check failed"
fi

if printf '%s\n' "$committable_files" | grep -E '^(docs|research|plans)(/|$)' >/dev/null 2>&1; then
  fail "project documentation belongs in Obsidian, not this repository"
fi

if printf '%s\n' "$committable_files" | while IFS= read -r path; do
  [ -n "$path" ] || continue
  [ -f "$path" ] || continue
  size=$(wc -c <"$path")
  [ "$size" -le 10485760 ] || exit 1
done; then
  :
else
  fail "large files should not be committed"
fi

printf '%s\n' 'repository checks passed'
