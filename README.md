# is01-linux

au/Sharp IS01 で Linux userspace を動かし、最終的に Codex CLI、SSH client、日本語入力を実用するための作業リポジトリ。

プロジェクト文書、調査メモ、ロードマップは Obsidian 側を正本にする。

```text
/home/boxp/Documents/obsidian-headless/BOXP/Projects/is01
```

このリポジトリには、IS01で動作させるimageを再現可能に作るためのソースコード、patch、config、CI pipeline、検証スクリプト、ビルド補助、実機操作を安全にするためのツールを置く。

## Repository deliverables

- kernel/rootfs/initramfs/image を生成するためのソース、設定、patch、build scripts
- GitHub Actions などのCI pipeline
- image生成後の検証スクリプト
- 実機flashやrestoreを安全に行うためのdry-run firstな補助スクリプト

生成済みimage、NAND dump、実機固有バックアップ、個人情報を含むログは原則としてgit commitしない。必要な場合はGitHub Actions artifact、release asset、またはローカル保管を使い、repoにはsha256と再生成手順を置く。

## Commands

```sh
make check
make lint
make fmt
make phase1-fetch
make phase1-initramfs
make phase1-kernel
make phase1-recovery
make phase1-verify
make phase1-repack-stock-recovery
make phase1-repack-stock-verify
make phase1-stock-kernel-custom-initramfs-recovery
make phase1-stock-kernel-custom-initramfs-verify
make phase1-stock-kernel-raw-initramfs-recovery
make phase1-stock-kernel-raw-initramfs-verify
make phase2-initramfs
make phase2-initramfs-verify
make phase2-recovery
make phase2-verify
make phase2-buildroot-rootfs
make phase2-buildroot-rootfs-verify
make phase2-buildroot-recovery
make phase2-buildroot-recovery-verify
make phase3-mainline-fetch
make phase3-initramfs
make phase3-initramfs-verify
make phase3-mainline-config-verify
make phase3-mainline-boot
make phase3-mainline-boot-verify
make phase3-mainline-recovery
make phase3-mainline-boot-entry-probes
make phase3-mainline-boot-entry-probes-verify
```

`make phase1-recovery` creates a recovery-partition candidate under `build/phase1/recovery/` for manual device testing. The repository does not run `flash_image` or write to the IS01.

`make phase1-repack-stock-recovery` extracts the `boot` UBI volume from a local stock `mtd2-recovery.img` backup and repacks it without changing the Android boot image payload. Set `STOCK_RECOVERY_IMG=/path/to/mtd2-recovery.img` when the backup is not in the default Obsidian vault path.

`make phase1-stock-kernel-custom-initramfs-recovery` builds a diagnostic recovery image that preserves the stock recovery kernel and Android boot header, replacing only the ramdisk with the Phase 1 initramfs. It requires a local stock `mtd2-recovery.img` backup and is intended to split kernel boot issues from initramfs/init issues.

`make phase1-stock-kernel-raw-initramfs-recovery` is a follow-up diagnostic target that preserves the stock recovery kernel and Android boot header, but uses the IS01 boot image's 4096-byte section alignment and an uncompressed `newc` cpio ramdisk.

`make phase2-initramfs` builds the Phase 2 minimal userspace initramfs. It provides a small static ARM `/init` shell for manual console/framebuffer/proc/UTF-8/reboot checks.

`make phase2-recovery` packages that Phase 2 initramfs with the stock recovery kernel using the same IS01 4096-byte boot image section alignment that passed Phase 1 device testing. It requires a local stock `mtd2-recovery.img` backup.

`make phase2-buildroot-rootfs` builds the Phase 2 BusyBox/Dropbear rootfs with pinned Buildroot 2015.02, Linux 2.6.29 headers, uClibc, static target binaries, and a raw `newc` cpio output. `make phase2-buildroot-recovery` packages that rootfs with the same stock recovery kernel path for manual device verification.

`make phase3-mainline-fetch` fetches pinned Linux 6.12.94 source from kernel.org. `make phase3-mainline-boot` builds a mainline ARM `zImage` with an appended minimal IS01 DTB and a raw Phase 3 initramfs, using the 4096-byte Android boot image section alignment observed on stock recovery. The initramfs writes a marker to `/dev/console`, waits 20 seconds, then asks the kernel to reboot so manual testing can distinguish userspace reachability without relying on UART. `make phase3-mainline-recovery` packages the generated Android boot payload into an IS01-sized UBI recovery candidate; when a local stock `mtd2-recovery.img` backup is present, its UBI image sequence number is preserved.

`make phase3-mainline-boot-entry-probes` reuses the Phase 3 mainline kernel payload to produce manual-test recovery candidates with varied Android boot header cmdline/alignment choices. These candidates are intended to split bootloader/header handoff problems from later kernel/initramfs failures after the baseline Phase 3 image stops at the stock splash screen.
