---
description: 変更をステージング・コミットする（メッセージは自動生成）
allowed-tools:
  - Bash
---

1. `git status` と `git diff` で変更内容を把握する。
2. `git log --oneline -5` でこのリポジトリのコミットメッセージスタイルを確認する。
3. 関連する変更・新規ファイルをステージング（`.env`・認証情報・大容量バイナリは除外）。
4. コミットメッセージを作成: 命令形、件名 ≤72 文字、WHY を中心に。
5. 以下を末尾に付けてコミット:
   `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`

push はしない。完了後にコミットハッシュとメッセージを報告すること。
