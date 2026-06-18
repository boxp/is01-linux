# AGENTS.md

- ユーザーには日本語で受け答えすること。
- このリポジトリは IS01 Linux bring-up の成果物、ビルド補助、CI、検証スクリプトを置く場所。
- プロジェクト文書の正本は Obsidian vault の `/home/boxp/Documents/obsidian-headless/BOXP/Projects/is01` に置くこと。
- リポジトリには長文調査メモ、作業ログ、設計メモを増やさない。必要な場合は Obsidian 側に作成し、READMEから短く参照する。
- 進捗管理の正本は `/home/boxp/Documents/obsidian-headless/BOXP/Projects/is01/todo.md` とし、レーンは `TODO` / `In Progress` / `Done` / `Blocked` を使うこと。
- 作業を始める前に対象項目を `In Progress` へ移し、作業中に状態が変わったら更新し、完了時は `Done` へ移すこと。外部要因やユーザー判断待ちで進められない場合は `Blocked` へ移すこと。
- このプロジェクトでは、ユーザーの指示を達成するために必要なPR作成・更新・マージは自律的に行ってよい。ただし、branch protection rule を必ず守り、必須CIが通過しない状態でマージしないこと。
- スクリプトを書く場合は、原則として shell script または Babashka (`bb`) を使うこと。
- TDDの原則にのっとり、必ずテストコードを先に書くこと。
- KISS・YAGNIの原則にのっとり、必要なコードだけを書くこと。
- 作業が完了したら codex review を行い、指摘事項がなくなるまで review → 修正 → review のループを行うこと。
- 破壊的な実機操作、flash、backup restore、partition write を行うコマンドは、必ずdry-runまたは明示的な確認ステップを用意すること。
- 実機から取得した個体固有情報、鍵、認証情報、NAND dump、巨大なバイナリ成果物はコミットしないこと。
- CIで検証できるものは `make check` から実行できるようにすること。
