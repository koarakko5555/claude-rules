---
name: improve
description: テスト・lint・レビューで改善点を 1 つ見つけて修正し、PR を作る（/loop や /schedule での自律実行用）
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
---

1 回の実行で改善を **1 件だけ** 行い、PR を作成する。`/loop /improve` や `/schedule` から繰り返し呼ばれる前提。

## 1. 前提確認

- `git status` が clean でなければ何もせず終了（人間の作業中の変更を巻き込まない）。
- `gh pr list --author @me --search "head:improve/"` で未マージの improve PR が 3 件以上あれば終了（レビュー待ちを溜めない）。
- `git checkout main && git pull -q`

## 2. 改善点の探索（上から順に、見つかった時点で止める）

1. テスト失敗 — `CLAUDE.md` の実行方法、なければ `package.json` / `pyproject.toml` 等から test コマンドを特定して実行。
2. lint / 型エラー。
3. `/code-review` 相当のレビュー — 直近 20 コミットで変更されたファイルを対象に、バグ・セキュリティ問題を探す。
4. テストの無い公開関数へのテスト追加。

何も見つからなければ「改善点なし」と報告して終了。

## 3. 修正

- ブランチ: `improve/<short-description>`
- 変更は ≤300 行、1 論理変更。`.claude/rules/coding.md` に従う。
- 修正後、手順 2 で使ったテスト・lint を再実行して通ることを確認する。通らなければブランチを破棄して終了。

## 4. PR 作成

変更ファイルを指定して `git add` → コミット → `gh pr create`。本文はサマリ箇条書き + テストプラン。

## 5. 学習の記録

見つけた問題が「Claude が書いたコードで再発しそうなパターン」なら、`/retro` の入力として記録する:

```bash
mkdir -p ~/.claude/feedback
jq -cn --arg ts "$(date -u +%FT%TZ)" --arg cwd "$PWD" --arg p "<問題パターンを 1 行で>" \
  '{ts: $ts, source: "improve", cwd: $cwd, prompt: $p}' >> ~/.claude/feedback/log.jsonl
```

## 厳守事項

- main に直接コミット・push しない。PR のマージは人間が行う。
- 仕様変更・機能追加はしない。挙動を変える修正はバグ修正に限る。
