# Phase 3 lean mainline candidate plan

## Goal

Prepare a Phase 3 recovery image that keeps the mainline timed-reboot probe behavior but reduces the kernel configuration to the smallest practical boot surface for IS01 verification.

## Scope

- Add a lean mainline Kconfig fragment for the Phase 3 candidate.
- Add build and verification scripts for the lean boot payload.
- Add a recovery image build target that packages the lean payload for `flash_image recovery`.
- Publish the lean image in the Phase 3 GitHub Actions artifact.
- Keep real-device flashing and observation as a human verification step.

## Verification gates

- `make check`
- `make phase3-mainline-config-verify`
- GitHub Actions `check`
- GitHub Actions `phase1`
- GitHub Actions `phase2`
- GitHub Actions `phase3`

## Merge condition

This work is mergeable when all PR checks pass and the Phase 3 artifact contains the lean recovery image with a recorded path and checksum for manual IS01 flashing.
