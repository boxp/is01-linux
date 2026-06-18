# AGENTS.md

- ユーザーには日本語で受け答えすること。
- このリポジトリは IS01 Linux bring-up の成果物、ビルド補助、CI、検証スクリプトを置く場所。
- プロジェクト文書の正本は Obsidian vault の `/home/boxp/Documents/obsidian-headless/BOXP/Projects/is01` に置くこと。
- リポジトリには長文調査メモ、作業ログ、設計メモを増やさない。必要な場合は Obsidian 側に作成し、READMEから短く参照する。
- スクリプトを書く場合は、原則として shell script または Babashka (`bb`) を使うこと。
- TDDの原則にのっとり、必ずテストコードを先に書くこと。
- KISS・YAGNIの原則にのっとり、必要なコードだけを書くこと。
- 作業が完了したら codex review を行い、指摘事項がなくなるまで review → 修正 → review のループを行うこと。
- 破壊的な実機操作、flash、backup restore、partition write を行うコマンドは、必ずdry-runまたは明示的な確認ステップを用意すること。
- 実機から取得した個体固有情報、鍵、認証情報、NAND dump、巨大なバイナリ成果物はコミットしないこと。
- CIで検証できるものは `make check` から実行できるようにすること。
