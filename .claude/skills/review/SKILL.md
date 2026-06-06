---
name: review
description: main ブランチからの差分をコードレビューする
allowed-tools:
  - Bash
  - Read
---

`main` から現在のブランチまでの差分をレビューしてください。各変更ファイルについて以下を確認:

1. ロジックバグ、off-by-one、エッジケース漏れ
2. セキュリティ上の問題（injection、シークレット露出、安全でないデシリアライズ）
3. 周辺コードへの意図しないリグレッション
4. 命名・可読性の懸念

報告は優先度別の箇条書きで: **Critical** / **Warning** / **Suggestion**。
linter で自動検出される類のスタイル指摘は省略してよい。

```bash
git diff main...HEAD
```
