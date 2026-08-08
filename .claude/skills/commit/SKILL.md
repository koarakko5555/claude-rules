---
name: commit
description: 変更をステージング・コミットする（メッセージは自動生成）
allowed-tools:
  - Bash
---

1. `git status` と `git diff` で変更内容を把握する。
2. `git log --oneline -5` でこのリポジトリのコミットメッセージスタイルを確認する。
3. 関連する変更・新規ファイルをステージング（`.env`・認証情報・大容量バイナリは除外）。
4. コミットメッセージを作成: 命令形、件名 ≤72 文字、WHY を中心に。
5. 以下を末尾に付けてコミット（モデル名は実行中のモデルに置き換える。例: `Claude Opus 5`）:
   `Co-Authored-By: Claude <MODEL> <noreply@anthropic.com>`

push はしない。完了後にコミットハッシュとメッセージを報告すること。
