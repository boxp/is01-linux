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
```

`make phase1-recovery` creates a recovery-partition candidate under `build/phase1/recovery/` for manual device testing. The repository does not run `flash_image` or write to the IS01.

`make phase1-repack-stock-recovery` extracts the `boot` UBI volume from a local stock `mtd2-recovery.img` backup and repacks it without changing the Android boot image payload. Set `STOCK_RECOVERY_IMG=/path/to/mtd2-recovery.img` when the backup is not in the default Obsidian vault path.

`make phase1-stock-kernel-custom-initramfs-recovery` builds a diagnostic recovery image that preserves the stock recovery kernel and Android boot header, replacing only the ramdisk with the Phase 1 initramfs. It requires a local stock `mtd2-recovery.img` backup and is intended to split kernel boot issues from initramfs/init issues.

`make phase1-stock-kernel-raw-initramfs-recovery` is a follow-up diagnostic target that preserves the stock recovery kernel and Android boot header, but uses the IS01 boot image's 4096-byte section alignment and an uncompressed `newc` cpio ramdisk.
