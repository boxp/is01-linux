# Phase 1 manual verification checklist

Codex does not write to the IS01 or perform boot verification. Human verification starts only after the repository has produced and inspected the Phase 1 artifacts.

## Build artifacts

Run:

```sh
make phase1-fetch
make phase1-initramfs
make phase1-kernel
make phase1-recovery
make phase1-verify
```

Expected outputs:

- `build/phase1/initramfs/mininit`
- `build/phase1/initramfs/initramfs.cpio`
- `build/phase1/initramfs/initramfs.cpio.gz`
- `build/kernel-out/arch/arm/boot/zImage`
- `build/phase1/recovery/phase1-boot.img`
- `build/phase1/recovery/phase1-recovery.img`
- `build/phase1/SHA256SUMS`

## Stock image inspection

The stock `mtd0-boot.img` and `mtd2-recovery.img` backups are UBI images, not Android boot images. Before preparing a recovery experiment image, inspect the local backups:

```sh
./scripts/inspect-stock-image.sh /path/to/mtd2-recovery.img
```

Record the output in Obsidian under `Projects/is01/logs/boot/`.

## Human-only device write boundary

This repository intentionally does not include a script that runs `flash_image` against the device. Use `scripts/prepare-recovery-flash.sh build/phase1/recovery/phase1-recovery.img` to generate a checklist and exact commands, then execute them manually only after confirming:

- the target partition is `recovery`;
- the image sha256 matches the expected value;
- the stock `mtd2-recovery.img` backup is locally available;
- the stock recovery restore command is ready;
- the device has sufficient battery and stable USB/ADB connection.

## Restore path

If a recovery experiment fails, restore the stock recovery image manually:

```sh
adb push mtd2-recovery.img /sdcard/is01-restore/mtd2-recovery.img
printf '/system/bin/flash_image recovery /sdcard/is01-restore/mtd2-recovery.img\nexit\n' | adb shell /sbin/au
```

Confirm sha256 before running the write command.
